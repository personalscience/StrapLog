import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("Raw accelerometer (acc)")
struct RawMotionTests {
    private func rows(_ rig: TestRig) throws -> [Row] {
        try rig.database.writer.read { try Row.fetchAll($0, sql: "SELECT * FROM acc ORDER BY recording_id, idx") }
    }

    @Test("an ordinary recording keeps no raw samples")
    func offByDefault() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "x")
        try await rig.play([.wait(ms: 960), motion(), .wait(ms: 1000), motion()])
        #expect(try rig.count("motion") == 1)
        #expect(try rig.count("acc") == 0)
    }

    @Test("a rawMotion recording keeps every sample, numbered, at the times motion uses")
    func everySample() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "training", rawMotion: true)
        try await rig.play([.wait(ms: 960), motion(), .wait(ms: 1000), motion(), .wait(ms: 500), motion(10)])
        let rows = try rows(rig)
        #expect(rows.count == 60)
        #expect(rows.map { $0["idx"] as Int64 } == Array(0..<60))
        #expect(rows.allSatisfy { ($0["recording_id"] as Int64) == id && ($0["z_mg"] as Int) == 1000 })
        let times = rows.map { $0["at_ms"] as Int64 }
        #expect(times == times.sorted())
        // The first batch fills one whole second; its last sample arrived at receipt.
        let start = try #require(try rig.recording(id)).startedAtMs
        #expect(times[24] == start + 960)
        #expect(times[0] == start)
        #expect(try DBInvariants.violations(rig.database.writer).isEmpty)
    }

    @Test("raw capture ends with the recording; the next one starts clean")
    func endsWithRecording() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "training", rawMotion: true)
        try await rig.play([.wait(ms: 960), motion()])
        try await rig.session.stop()
        try await rig.session.start(name: "plain")
        try await rig.play([.wait(ms: 1000), motion()])
        #expect(try rig.count("acc") == 25)
    }

    @Test("a relaunch stops raw capture: the run that wanted it is gone")
    func relaunchStops() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "training", rawMotion: true)
        try await rig.play([.wait(ms: 960), motion()])
        let resumed = rig.relaunched()
        try await resumed.resumeIfOpen()
        try await FakeHeartSource(clock: rig.clock, script: [.wait(ms: 1000), motion()]).pump(into: resumed)
        #expect(try rig.count("acc") == 25)
    }

    @Test("DBInvariants catch acc times going backwards")
    func invariant() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "training", rawMotion: true)
        try await rig.play([.wait(ms: 960), motion()])
        try await rig.database.writer.write { db in
            try db.execute(sql: "UPDATE acc SET at_ms = at_ms - 5000 WHERE recording_id = ? AND idx = 10", arguments: [id])
        }
        #expect(try DBInvariants.violations(rig.database.writer) == ["acc \(id)/10: at_ms goes backwards"])
    }
}
