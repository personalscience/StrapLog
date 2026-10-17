import Foundation
import GRDB

/// The single writer of recording data. Turns sensor events and user actions into rows,
/// one transaction per call, and survives app death: a relaunch calls `resumeIfOpen`,
/// which reattaches to the unfinished recording instead of starting a new one.
///
/// Link and battery state are tracked even when idle, so a recording started while the
/// strap is already connected opens with a `connect` event and a `battery_start`.
public actor RecordingSession {
    private enum Link: Equatable {
        case unknown
        case connected(deviceId: String, firmware: String?)
        case disconnected
    }

    private let database: StrapLogDatabase
    private let clock: any WallClock
    private let staleAfterMs: Int64
    private var link = Link.unknown
    private var lastBattery: Int?
    private var phase: AppPhase?
    /// Time of the active recording's latest snapshot, or its start; drives `snapshotIfDue`.
    private var lastSnapshotMs: Int64?
    /// Per-second accelerometer reduction for the active recording.
    private var motion: MotionReducer?
    /// The active recording's auto-stop plan; nil unless its preset is `overnight`.
    private var plan: OvernightPlan?
    /// Posture of the active overnight recording, rebuilt from scratch after a relaunch.
    private var posture = PostureTracker()
    /// When the active overnight recording's resting reading began, restored after a relaunch.
    private var restingStartMs: Int64?
    private let uprightStopMs: Int64
    /// Written into each export's `meta` and `index.json`.
    private let appVersion: String

    /// The recording being written, or nil when idle.
    public private(set) var recordingId: Int64?

    /// `stop` note on a recording closed by `resumeIfOpen` because it went stale.
    public static let staleNote = "stale"

    /// Default `staleAfterMs`: 6 h. Generous on purpose: closing too early drops the rest
    /// of a night, while resuming too late only inflates duration across a bracketed gap.
    public static let defaultStaleAfterMs: Int64 = 6 * 3_600_000

    /// Strap battery at or below this logs one `low_battery` event per recording.
    public static let lowBatteryPercent = 10

    public init(database: StrapLogDatabase, clock: any WallClock = SystemClock(),
                staleAfterMs: Int64 = RecordingSession.defaultStaleAfterMs,
                uprightStopMs: Int64 = OvernightPlan.defaultUprightStopMs,
                appVersion: String = "dev") {
        self.database = database
        self.appVersion = appVersion
        self.clock = clock
        self.staleAfterMs = staleAfterMs
        self.uprightStopMs = uprightStopMs
    }

    // MARK: User actions

    /// Starts a recording of `activity`; an empty `name` becomes `activity.defaultName`.
    /// An `overnight` activity keeps `plan` (default: no wake time) in `recording.context`.
    @discardableResult
    public func start(_ activity: ActivityPreset = .other, name: String,
                      plan: OvernightPlan = OvernightPlan(wakeAtMs: nil)) throws -> Int64 {
        let plan = activity.overnight ? plan : nil
        guard recordingId == nil else { throw RecordingSessionError.alreadyRecording }
        let now = clock.nowMs()
        let tz = clock.tzOffsetSeconds(atMs: now)
        let link = self.link
        let battery = lastBattery
        let id = try database.writer.write { db -> Int64 in
            if let open = try Recording.open(db), let openId = open.id {
                throw RecordingSessionError.openRecordingExists(id: openId)
            }
            var rec = Recording(name: name.isEmpty ? activity.defaultName(atMs: now, tzOffsetS: tz) : name,
                                activity: activity.id, startedAtMs: now, tzOffsetS: tz)
            rec.context = plan?.contextJSON
            rec.batteryStart = battery
            rec.batteryEnd = battery
            if case .connected(let deviceId, let firmware) = link {
                rec.deviceId = deviceId
                rec.firmware = firmware
            }
            try rec.insert(db)
            let id = rec.id!
            var start = RecordingEvent(recordingId: id, atMs: now, kind: .start)
            try start.insert(db)
            if case .connected(let deviceId, _) = link {
                var connect = RecordingEvent(recordingId: id, atMs: now, kind: .connect, note: deviceId)
                try connect.insert(db)
            }
            return id
        }
        attach(id, lastSnapshotMs: now, plan: plan)
        return id
    }

    /// Ends the recording, noting `reason` if it stopped itself. With `directory`, also logs a
    /// `snapshot` event and exports `Snapshot.fileName(for:)` there, after the stop is committed
    /// so the file includes it.
    @discardableResult
    public func stop(because reason: AutoStop? = nil, snapshotInto directory: URL? = nil) throws -> Recording {
        let id = try requireRecording()
        let now = clock.nowMs()
        let lastMotion = motion?.flush()
        let rec = try database.writer.write { db -> Recording in
            try MotionSecond.save(lastMotion.map { [$0] } ?? [], db: db)
            if reason == .wakeTime, restingStartMs != nil {
                var end = RecordingEvent(recordingId: id, atMs: now, kind: .marker, label: OvernightPlan.restingEndLabel)
                try end.insert(db)
            }
            let rec = try Self.finish(id, atMs: now, note: reason?.rawValue, db: db)
            if directory != nil {
                var snap = RecordingEvent(recordingId: id, atMs: now, kind: .snapshot,
                                          note: Snapshot.fileName(for: rec))
                try snap.insert(db)
            }
            return rec
        }
        detach()
        if let directory { try export(rec, id: id, into: directory) }
        return rec
    }

    /// `marker` event with a preset `label`, free-text `note`, or both. Returns the stored row.
    @discardableResult
    public func marker(label: String? = nil, note: String? = nil) throws -> RecordingEvent {
        let id = try requireRecording()
        return try log(.marker, label: label, note: note, recordingId: id, atMs: clock.nowMs())
    }

    /// Starts a breathing pacer now and logs `pacer_start` noted with its rate.
    public func startPacer(breathsPerMinute: Double) throws -> BreathingPacer {
        let id = try requireRecording()
        let pacer = BreathingPacer(breathsPerMinute: breathsPerMinute, startedAtMs: clock.nowMs())
        try log(.pacerStart, note: pacer.note, recordingId: id, atMs: pacer.startedAtMs)
        return pacer
    }

    public func stopPacer() throws {
        let id = try requireRecording()
        try log(.pacerStop, note: nil, recordingId: id, atMs: clock.nowMs())
    }

    /// Deletes a finished recording and all its rows (foreign keys cascade). Returns it, so the
    /// caller can remove its snapshot file. The recording being written cannot be deleted.
    @discardableResult
    public func delete(_ id: Int64) throws -> Recording {
        guard id != recordingId else { throw RecordingSessionError.cannotDeleteActive }
        return try database.writer.write { db in
            guard let rec = try Recording.fetchOne(db, key: id) else {
                throw RecordingSessionError.noSuchRecording(id: id)
            }
            guard rec.endedAtMs != nil else { throw RecordingSessionError.cannotDeleteActive }
            try rec.delete(db)
            return rec
        }
    }

    /// Periodic mid-recording export: logs a `snapshot` event, then overwrites the file.
    @discardableResult
    public func snapshot(into directory: URL) throws -> URL {
        let id = try requireRecording()
        let rec = try database.writer.read { db in try Recording.fetchOne(db, key: id) }
        guard let rec else { throw RecordingSessionError.notRecording }
        let now = clock.nowMs()
        try log(.snapshot, note: Snapshot.fileName(for: rec), recordingId: id, atMs: now)
        lastSnapshotMs = now
        return try export(rec, id: id, into: directory)
    }

    /// Rewrites `directory`'s `index.json`, e.g. after a snapshot file was removed from it.
    public func reindex(_ directory: URL) throws {
        try ExportIndex.refresh(database, in: directory, appVersion: appVersion, nowMs: clock.nowMs())
    }

    /// `snapshot(into:)` if at least `everyMs` has passed since the recording's last snapshot
    /// (or its start). Called after each HR notification, so the cadence needs no timer:
    /// while the strap is streaming, Bluetooth keeps the app running in the background.
    @discardableResult
    public func snapshotIfDue(into directory: URL, everyMs: Int64) throws -> URL? {
        guard recordingId != nil, let last = lastSnapshotMs, clock.nowMs() - last >= everyMs else { return nil }
        return try snapshot(into: directory)
    }

    /// At the wake time, logs the `resting_start` marker and returns it, unless the body is already
    /// upright or the reading has begun. Checked after each sensor event, before `autoStopDue`.
    @discardableResult
    public func beginRestingIfDue() throws -> RecordingEvent? {
        guard let id = recordingId, let wake = plan?.wakeAtMs, restingStartMs == nil,
              posture.posture != .upright else { return nil }
        let now = clock.nowMs()
        guard now >= wake else { return nil }
        restingStartMs = now
        return try log(.marker, label: OvernightPlan.restingStartLabel, note: nil, recordingId: id, atMs: now)
    }

    /// Why the active overnight recording should stop itself now, or nil. Checked after each
    /// sensor event, like `snapshotIfDue`, so it needs no timer. From the wake time it waits out
    /// the resting reading, unless the body was already upright and there is nothing to wait for.
    public func autoStopDue() -> AutoStop? {
        guard recordingId != nil, let plan else { return nil }
        let now = clock.nowMs()
        if let wake = plan.wakeAtMs, now >= wake {
            if let start = restingStartMs, now - start >= OvernightPlan.restingMs { return .wakeTime }
            if restingStartMs == nil, posture.posture == .upright { return .wakeTime }
        }
        if posture.uprightAfterLyingMs >= uprightStopMs { return .upright }
        return nil
    }

    /// Records a foreground/background transition; logged only while recording and only on change.
    public func appPhase(_ newPhase: AppPhase) throws {
        guard newPhase != phase else { return }
        phase = newPhase
        guard let id = recordingId else { return }
        try log(newPhase.eventKind, note: nil, recordingId: id, atMs: clock.nowMs())
    }

    /// After a launch: reattach to an unfinished recording, logging `relaunch`.
    /// Returns its id, or nil if every recording is finished. Idempotent within a process.
    ///
    /// A recording silent for longer than `staleAfterMs` was abandoned, not interrupted:
    /// it is closed at its last activity with a `stop` noted `stale`, and nil is returned.
    @discardableResult
    public func resumeIfOpen() throws -> Int64? {
        if let recordingId { return recordingId }
        let now = clock.nowMs()
        let staleAfterMs = self.staleAfterMs
        let resumed = try database.writer.write { db -> (id: Int64, lastSnapshotMs: Int64, rec: Recording, restingStartMs: Int64?)? in
            guard let open = try Recording.open(db), let id = open.id else { return nil }
            let last = try Self.lastActivityMs(id, db: db) ?? open.startedAtMs
            if now - last > staleAfterMs {
                try Self.finish(id, atMs: last, note: Self.staleNote, db: db)
                return nil
            }
            var relaunch = RecordingEvent(recordingId: id, atMs: now, kind: .relaunch)
            try relaunch.insert(db)
            let lastSnapshot = try Int64.fetchOne(db, sql: """
                SELECT MAX(at_ms) FROM event WHERE recording_id = ? AND kind = 'snapshot'
                """, arguments: [id])
            let restingStart = try Int64.fetchOne(db, sql: """
                SELECT MIN(at_ms) FROM event WHERE recording_id = ? AND kind = 'marker' AND label = ?
                """, arguments: [id, OvernightPlan.restingStartLabel])
            return (id, lastSnapshot ?? open.startedAtMs, open, restingStart)
        }
        guard let resumed else { return nil }
        let overnight = ActivityPreset.named(resumed.rec.activity).overnight
        attach(resumed.id, lastSnapshotMs: resumed.lastSnapshotMs,
               plan: overnight ? OvernightPlan(contextJSON: resumed.rec.context) : nil)
        restingStartMs = resumed.restingStartMs
        return resumed.id
    }

    // MARK: Sensor events

    public func ingest(_ event: SensorEvent) throws {
        switch event.payload {
        case .heartRate(let bpm, let contact, let rr1024):
            guard let id = recordingId else { return }
            try database.writer.write { db in
                var n = HeartNotification(recordingId: id, receivedAtMs: event.atMs, hrBpm: bpm,
                                          contact: contact, nRR: rr1024.count)
                try n.insert(db)
                let ends = BeatTiming.endTimesMs(receivedAtMs: event.atMs, rr1024: rr1024)
                for (i, rr) in rr1024.enumerated() {
                    var beat = Beat(recordingId: id, notificationId: n.id!, idx: i, rr1024: rr, tEndMsEst: ends[i])
                    try beat.insert(db)
                }
            }

        case .connected(let deviceId, let firmware):
            let wasConnected = if case .connected = link { true } else { false }
            link = .connected(deviceId: deviceId, firmware: firmware)
            guard let id = recordingId, !wasConnected else { return }
            try database.writer.write { db in
                try db.execute(sql: """
                    UPDATE recording SET device_id = COALESCE(device_id, ?), firmware = COALESCE(firmware, ?)
                    WHERE id = ?
                    """, arguments: [deviceId, firmware, id])
                var e = RecordingEvent(recordingId: id, atMs: event.atMs, kind: .connect, note: deviceId)
                try e.insert(db)
            }

        case .disconnected(let reason):
            guard link != .disconnected else { return }
            link = .disconnected
            guard let id = recordingId else { return }
            try log(.disconnect, note: reason, recordingId: id, atMs: event.atMs)

        case .battery(let percent):
            lastBattery = percent
            guard let id = recordingId else { return }
            try database.writer.write { db in
                try db.execute(sql: """
                    UPDATE recording SET battery_start = COALESCE(battery_start, ?), battery_end = ?
                    WHERE id = ?
                    """, arguments: [percent, percent, id])
                guard percent <= Self.lowBatteryPercent else { return }
                let logged = try RecordingEvent
                    .filter(sql: "recording_id = ? AND kind = ?", arguments: [id, EventKind.lowBattery.rawValue])
                    .fetchCount(db) > 0
                guard !logged else { return }
                var e = RecordingEvent(recordingId: id, atMs: event.atMs, kind: .lowBattery, note: "\(percent)%")
                try e.insert(db)
            }

        case .firmware(let version):
            guard case .connected(let deviceId, _) = link else { return }
            link = .connected(deviceId: deviceId, firmware: version)
            guard let id = recordingId else { return }
            try database.writer.write { db in
                try db.execute(sql: "UPDATE recording SET firmware = COALESCE(firmware, ?) WHERE id = ?",
                               arguments: [version, id])
            }

        case .serialNumber:
            break

        case .bluetooth(let poweredOn):
            guard let id = recordingId else { return }
            try log(poweredOn ? .bleOn : .bleOff, note: nil, recordingId: id, atMs: event.atMs)

        case .motion(let samples):
            guard let id = recordingId, let seconds = motion?.add(receivedAtMs: event.atMs, samples: samples),
                  !seconds.isEmpty else { return }
            let changes = plan == nil ? [] : posture.add(seconds)
            try database.writer.write { db in
                try MotionSecond.save(seconds, db: db)
                for change in changes {
                    var e = RecordingEvent(recordingId: id, atMs: change.atMs, kind: .posture, note: change.posture.rawValue)
                    try e.insert(db)
                }
            }
        }
    }

    // MARK: Helpers

    /// Writes the snapshot of `rec`, described by `ExportMeta`, then refreshes the folder's index.
    @discardableResult
    private func export(_ rec: Recording, id: Int64, into directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(Snapshot.fileName(for: rec))
        try Snapshot.write(database, recordingId: id, to: url,
                           meta: ExportMeta.rows(for: rec, appVersion: appVersion, exportedAtMs: clock.nowMs()))
        try reindex(directory)
        return url
    }

    private func attach(_ id: Int64, lastSnapshotMs: Int64, plan: OvernightPlan?) {
        recordingId = id
        self.lastSnapshotMs = lastSnapshotMs
        motion = MotionReducer(recordingId: id)
        self.plan = plan
        posture = PostureTracker()
        restingStartMs = nil
    }

    private func detach() {
        recordingId = nil
        lastSnapshotMs = nil
        motion = nil
        plan = nil
        posture = PostureTracker()
        restingStartMs = nil
    }

    /// Sets `ended_at_ms` and logs the `stop` event in the caller's transaction.
    @discardableResult
    private static func finish(_ id: Int64, atMs: Int64, note: String?, db: Database) throws -> Recording {
        guard var rec = try Recording.fetchOne(db, key: id) else { throw RecordingSessionError.notRecording }
        rec.endedAtMs = atMs
        try rec.update(db)
        var stop = RecordingEvent(recordingId: id, atMs: atMs, kind: .stop, note: note)
        try stop.insert(db)
        return rec
    }

    /// Latest event or notification time in the recording, or nil if it has neither.
    private static func lastActivityMs(_ id: Int64, db: Database) throws -> Int64? {
        try Int64.fetchOne(db, sql: """
            SELECT MAX(t) FROM (
                SELECT MAX(at_ms) AS t FROM event WHERE recording_id = ?
                UNION ALL
                SELECT MAX(received_at_ms) FROM notification WHERE recording_id = ?)
            """, arguments: [id, id])
    }

    private func requireRecording() throws -> Int64 {
        guard let recordingId else { throw RecordingSessionError.notRecording }
        return recordingId
    }

    @discardableResult
    private func log(_ kind: EventKind, label: String? = nil, note: String?, recordingId: Int64,
                     atMs: Int64) throws -> RecordingEvent {
        try database.writer.write { db in
            var e = RecordingEvent(recordingId: recordingId, atMs: atMs, kind: kind, label: label, note: note)
            try e.insert(db)
            return e
        }
    }
}
