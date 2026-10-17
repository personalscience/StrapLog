import Foundation
import GRDB
import Testing
@testable import StrapLogCore

/// A 25 Hz still batch received now, its last sample at receipt (so it spans the 960 ms before).
/// Tests wait 960 ms after a whole-second start so each batch fills a single second.
func motion(_ count: Int = 25, z: Int = 1000) -> FakeHeartSource.Step {
    .emit(.motion(samples: acc(count) { _ in (0, 0, z) }))
}

@Suite("Motion in RecordingSession")
struct MotionSessionTests {
    func seconds(_ rig: TestRig) throws -> [MotionSecond] {
        try rig.database.writer.read { try MotionSecond.order(sql: "second_ms").fetchAll($0) }
    }

    @Test("ACC is ignored when idle, and written without any HR while recording")
    func accWithoutHR() async throws {
        let rig = try TestRig()
        try await rig.play([motion(), .wait(ms: 1000), motion()])
        #expect(try rig.count("motion") == 0)

        let id = try await rig.session.start(name: "acc only")
        try await rig.play([.wait(ms: 960), motion(), .wait(ms: 1000), motion(), .wait(ms: 1000), motion()])
        #expect(try rig.count("notification") == 0)
        let rows = try seconds(rig)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.recordingId == id })
        #expect(rows.map(\.secondMs) == rows.map(\.secondMs).sorted())
    }

    @Test("ACC interleaved with HR leaves beats and motion each intact")
    func interleaved() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "mixed")
        try await rig.play([.wait(ms: 960), motion(), hr([1024]), .wait(ms: 1000), hr([1024]), motion(), .wait(ms: 1000), motion()])
        #expect(try rig.count("beat") == 2)
        #expect(try rig.count("motion") == 2)
        #expect(try DBInvariants.violations(rig.database.writer).isEmpty)
    }

    @Test("Stop flushes the partial last second")
    func stopFlushes() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "x")
        try await rig.play([.wait(ms: 960), motion(10)])
        #expect(try rig.count("motion") == 0)
        try await rig.session.stop()
        #expect(try seconds(rig).map(\.n) == [10])
    }

    @Test("a relaunch mid-second merges into the row already stored")
    func relaunchMerges() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "night")
        // 10 samples ending 600 ms into a second, then the second closes on the next batch.
        rig.clock.advance(byMs: 600)
        try await rig.play([motion(10), .wait(ms: 400), motion(1)])
        let resumed = rig.relaunched()
        try await resumed.resumeIfOpen()
        // Killed holding 1 sample of the next second. The relaunched reducer's first batch is
        // backdated into the second already written: 3 samples merge into it, 2 open the next.
        try await FakeHeartSource(clock: rig.clock, script: [.wait(ms: 40), motion(5)]).pump(into: resumed)
        try await resumed.stop()
        #expect(try seconds(rig).map(\.n) == [13, 2])
    }

    @Test("an 8 h night of motion adds under 1 MB to an export")
    func nightlySize() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = try StrapLogDatabase.live(at: dir.appendingPathComponent("live.sqlite"))
        let rig = try TestRig(database: db)
        let id = try await rig.session.start(name: "overnight")
        let empty = dir.appendingPathComponent("empty.sqlite")
        try Snapshot.write(db, recordingId: id, to: empty)

        let start = rig.clock.nowMs()
        var g = SystemRandomNumberGenerator()
        let night = (0..<(8 * 3600)).map { s in
            MotionSecond(recordingId: id, secondMs: start + Int64(s) * 1000, rmsMg: Double(Int.random(in: 0...60, using: &g)),
                         gxMg: Double(Int.random(in: -1000...1000, using: &g)), gyMg: Double(Int.random(in: -1000...1000, using: &g)),
                         gzMg: Double(Int.random(in: -1000...1000, using: &g)), n: 25)
        }
        try await db.writer.write { try MotionSecond.save(night, db: $0) }
        let full = dir.appendingPathComponent("full.sqlite")
        try Snapshot.write(db, recordingId: id, to: full)

        func size(_ url: URL) throws -> Int { try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! Int }
        let added = try size(full) - size(empty)
        #expect(added < 1_000_000, "motion adds \(added) bytes per night")
    }
}
