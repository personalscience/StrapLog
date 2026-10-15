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
    private var link = Link.unknown
    private var lastBattery: Int?

    /// The recording being written, or nil when idle.
    public private(set) var recordingId: Int64?

    public init(database: StrapLogDatabase, clock: any WallClock = SystemClock()) {
        self.database = database
        self.clock = clock
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
        return id
    }

    /// Ends the recording. With `directory`, also logs a `snapshot` event and writes
    /// `Snapshot.fileName(for:)` there, after the stop is committed so the file includes it.
    @discardableResult
    public func stop(snapshotInto directory: URL? = nil) throws -> Recording {
        let id = try requireRecording()
        let now = clock.nowMs()
        let rec = try database.writer.write { db -> Recording in
            guard var rec = try Recording.fetchOne(db, key: id) else {
                throw RecordingSessionError.notRecording
            }
            rec.endedAtMs = now
            try rec.update(db)
            var stop = RecordingEvent(recordingId: id, atMs: now, kind: .stop)
            try stop.insert(db)
            if directory != nil {
                var snap = RecordingEvent(recordingId: id, atMs: now, kind: .snapshot,
                                          note: Snapshot.fileName(for: rec))
                try snap.insert(db)
            }
            return rec
        }
        recordingId = nil
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

    /// Periodic mid-recording export: logs a `snapshot` event, then overwrites the file.
    @discardableResult
    public func snapshot(into directory: URL) throws -> URL {
        let id = try requireRecording()
        let rec = try database.writer.read { db in try Recording.fetchOne(db, key: id) }
        guard let rec else { throw RecordingSessionError.notRecording }
        let name = Snapshot.fileName(for: rec)
        try log(.snapshot, note: name, recordingId: id, atMs: clock.nowMs())
        let url = directory.appendingPathComponent(name)
        try Snapshot.write(database, to: url)
        return url
    }

    /// After a launch: reattach to an unfinished recording, logging `relaunch`.
    /// Returns its id, or nil if every recording is finished. Idempotent within a process.
    @discardableResult
    public func resumeIfOpen() throws -> Int64? {
        if let recordingId { return recordingId }
        let now = clock.nowMs()
        let id = try database.writer.write { db -> Int64? in
            guard let open = try Recording.open(db), let id = open.id else { return nil }
            var relaunch = RecordingEvent(recordingId: id, atMs: now, kind: .relaunch)
            try relaunch.insert(db)
            return id
        }
        recordingId = id
        return id
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
            }

        case .bluetooth(let poweredOn):
            guard let id = recordingId else { return }
            try log(poweredOn ? .bleOn : .bleOff, note: nil, recordingId: id, atMs: event.atMs)
        }
    }

    // MARK: Helpers

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
