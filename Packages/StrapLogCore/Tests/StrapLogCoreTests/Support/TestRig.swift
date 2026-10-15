import Foundation
import GRDB
@testable import StrapLogCore

/// A session on an in-memory database with a fake clock, plus read helpers.
struct TestRig {
    let database: StrapLogDatabase
    let clock: FakeClock
    let session: RecordingSession

    init(database: StrapLogDatabase? = nil, clock: FakeClock = FakeClock()) throws {
        self.database = try database ?? .inMemory()
        self.clock = clock
        self.session = RecordingSession(database: self.database, clock: clock)
    }

    /// A second session on the same database, as after the app was killed and relaunched.
    func relaunched() -> RecordingSession {
        RecordingSession(database: database, clock: clock)
    }

    func play(_ script: [FakeHeartSource.Step]) async throws {
        try await FakeHeartSource(clock: clock, script: script).pump(into: session)
    }

    func kinds(_ recordingId: Int64) throws -> [EventKind] {
        try events(recordingId).map(\.kind)
    }

    func events(_ recordingId: Int64) throws -> [RecordingEvent] {
        try database.writer.read { db in
            try RecordingEvent.filter(sql: "recording_id = ?", arguments: [recordingId])
                .order(sql: "id").fetchAll(db)
        }
    }

    func beats() throws -> [Beat] {
        try database.writer.read { try Beat.order(sql: "id").fetchAll($0) }
    }

    func notifications() throws -> [HeartNotification] {
        try database.writer.read { try HeartNotification.order(sql: "id").fetchAll($0) }
    }

    func recording(_ id: Int64) throws -> Recording? {
        try database.writer.read { try Recording.fetchOne($0, key: id) }
    }

    func count(_ table: String) throws -> Int {
        try database.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 }
    }
}

func hr(_ rr1024: [Int], bpm: Int = 60, contact: Bool? = true) -> FakeHeartSource.Step {
    .emit(.heartRate(bpm: bpm, contact: contact, rr1024: rr1024))
}

/// Unique scratch directory under the system temp dir; removed by the caller.
func scratchDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("StrapLogCoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
