import GRDB
import Testing
@testable import StrapLogCore

@Suite("DBInvariants")
struct DBInvariantsTests {
    private func healthyRig() async throws -> TestRig {
        let rig = try TestRig()
        try await rig.session.start(name: "x")
        try await rig.play([.wait(ms: 1000), hr([1000, 900]), .wait(ms: 1000), hr([950])])
        return rig
    }

    @Test("a session-written database is clean")
    func clean() async throws {
        #expect(try DBInvariants.violations(await healthyRig().database.writer).isEmpty)
    }

    @Test("missing beat breaks n_rr == count(beat)")
    func nRR() async throws {
        let rig = try await healthyRig()
        try await rig.database.writer.write { try $0.execute(sql: "DELETE FROM beat WHERE id = 1") }
        let v = try DBInvariants.violations(rig.database.writer)
        #expect(v.count == 1)
        #expect(v[0].contains("n_rr 2 != 1"))
    }

    @Test("rr_ms drift and backwards receive times are reported")
    func drift() async throws {
        let rig = try await healthyRig()
        try await rig.database.writer.write { db in
            try db.execute(sql: "UPDATE beat SET rr_ms = rr_ms + 1 WHERE id = 3")
            try db.execute(sql: "UPDATE notification SET received_at_ms = 0 WHERE id = 2")
        }
        let v = try DBInvariants.violations(rig.database.writer)
        #expect(v.contains { $0.hasPrefix("beat 3: rr_ms") })
        #expect(v.contains { $0.hasPrefix("notification 2: received_at_ms goes backwards") })
    }

    @Test("start/stop event counts must match recording state")
    func startStop() async throws {
        let rig = try await healthyRig()
        try await rig.database.writer.write { try $0.execute(sql: "UPDATE recording SET ended_at_ms = 1") }
        #expect(try DBInvariants.violations(rig.database.writer) == ["recording 1: 0 stop events, ended=true"])
    }
}
