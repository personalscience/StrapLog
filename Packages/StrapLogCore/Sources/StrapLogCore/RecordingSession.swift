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
                staleAfterMs: Int64 = RecordingSession.defaultStaleAfterMs) {
        self.database = database
        self.clock = clock
        self.staleAfterMs = staleAfterMs
    }

    // MARK: User actions

    @discardableResult
    public func start(name: String) throws -> Int64 {
        guard recordingId == nil else { throw RecordingSessionError.alreadyRecording }
        let now = clock.nowMs()
        let tz = clock.tzOffsetSeconds(atMs: now)
        let link = self.link
        let battery = lastBattery
        let id = try database.writer.write { db -> Int64 in
            if let open = try Recording.open(db), let openId = open.id {
                throw RecordingSessionError.openRecordingExists(id: openId)
            }
            var rec = Recording(name: name, startedAtMs: now, tzOffsetS: tz)
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
        recordingId = id
        lastSnapshotMs = now
        return id
    }

    /// Ends the recording. With `directory`, also logs a `snapshot` event and writes
    /// `Snapshot.fileName(for:)` there, after the stop is committed so the file includes it.
    @discardableResult
    public func stop(snapshotInto directory: URL? = nil) throws -> Recording {
        let id = try requireRecording()
        let now = clock.nowMs()
        let rec = try database.writer.write { db -> Recording in
            let rec = try Self.finish(id, atMs: now, note: nil, db: db)
            if directory != nil {
                var snap = RecordingEvent(recordingId: id, atMs: now, kind: .snapshot,
                                          note: Snapshot.fileName(for: rec))
                try snap.insert(db)
            }
            return rec
        }
        recordingId = nil
        lastSnapshotMs = nil
        if let directory {
            try Snapshot.write(database, to: directory.appendingPathComponent(Snapshot.fileName(for: rec)))
        }
        return rec
    }

    /// `marker` event; `note` is `a`, `b`, `c`, `end`, or free text. Returns the stored row.
    @discardableResult
    public func marker(_ note: String) throws -> RecordingEvent {
        let id = try requireRecording()
        return try log(.marker, note: note, recordingId: id, atMs: clock.nowMs())
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

    /// Periodic mid-recording export: logs a `snapshot` event, then overwrites the file.
    @discardableResult
    public func snapshot(into directory: URL) throws -> URL {
        let id = try requireRecording()
        let rec = try database.writer.read { db in try Recording.fetchOne(db, key: id) }
        guard let rec else { throw RecordingSessionError.notRecording }
        let name = Snapshot.fileName(for: rec)
        let now = clock.nowMs()
        try log(.snapshot, note: name, recordingId: id, atMs: now)
        lastSnapshotMs = now
        let url = directory.appendingPathComponent(name)
        try Snapshot.write(database, to: url)
        return url
    }

    /// `snapshot(into:)` if at least `everyMs` has passed since the recording's last snapshot
    /// (or its start). Called after each HR notification, so the cadence needs no timer:
    /// while the strap is streaming, Bluetooth keeps the app running in the background.
    @discardableResult
    public func snapshotIfDue(into directory: URL, everyMs: Int64) throws -> URL? {
        guard recordingId != nil, let last = lastSnapshotMs, clock.nowMs() - last >= everyMs else { return nil }
        return try snapshot(into: directory)
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
        let resumed = try database.writer.write { db -> (id: Int64, lastSnapshotMs: Int64)? in
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
            return (id, lastSnapshot ?? open.startedAtMs)
        }
        recordingId = resumed?.id
        lastSnapshotMs = resumed?.lastSnapshotMs
        return resumed?.id
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

        case .bluetooth(let poweredOn):
            guard let id = recordingId else { return }
            try log(poweredOn ? .bleOn : .bleOff, note: nil, recordingId: id, atMs: event.atMs)
        }
    }

    // MARK: Helpers

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
    private func log(_ kind: EventKind, note: String?, recordingId: Int64, atMs: Int64) throws -> RecordingEvent {
        try database.writer.write { db in
            var e = RecordingEvent(recordingId: recordingId, atMs: atMs, kind: kind, note: note)
            try e.insert(db)
            return e
        }
    }
}
