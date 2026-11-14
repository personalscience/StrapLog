import Foundation
import GRDB
import Testing
@testable import StrapLogCore

/// `n` PPG readings 31 ms apart from `fromMs`, counters from `counter`.
func ppg(_ n: Int, fromMs: Int64, counter: Int = 0, value: Int = 7500) -> FakeHeartSource.Step {
    .emit(.ppg(samples: (0..<n).map {
        PpgSample(receivedAtMs: fromMs + Int64($0) * 31, counter: (counter + $0) % 256, value: value + $0)
    }))
}

@Suite("PPG and arm placement in RecordingSession")
struct PpgSessionTests {
    // Synchronous, so the async test gets GRDB's blocking `read`.
    private func ppgRows(_ rig: TestRig) throws -> [[Int64]] {
        try rig.database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT recording_id, received_at_ms, counter, value FROM ppg ORDER BY received_at_ms, counter")
                .map { [$0[0], $0[1], $0[2], $0[3]] }
        }
    }

    @Test("PPG is written only while recording, one row per reading, in its recording")
    func written() async throws {
        let rig = try TestRig()
        try await rig.play([ppg(16, fromMs: rig.clock.nowMs())])
        #expect(try rig.count("ppg") == 0, "idle readings are not stored")

        let id = try await rig.session.start(name: "breath")
        let t0 = rig.clock.nowMs()
        try await rig.play([ppg(16, fromMs: t0, counter: 250), .wait(ms: 500), ppg(16, fromMs: t0 + 500, counter: 10)])
        let rows = try ppgRows(rig)
        #expect(rows.count == 32)
        #expect(rows.allSatisfy { $0[0] == id })
        #expect(rows.first?[2] == 250)
        #expect(rows[6][2] == 0, "the counter wraps at 256")
        #expect(rows.first?[1] == t0)
        try await rig.session.stop()
        try await rig.play([ppg(4, fromMs: rig.clock.nowMs(), counter: 40)])
        #expect(try rig.count("ppg") == 32)
    }

    @Test("an arm sensor logs no posture and never stops itself for being upright")
    func armPosture() async throws {
        let rig = try TestRig()
        let session = RecordingSession(database: rig.database, clock: rig.clock, uprightStopMs: 5 * 60_000)
        await session.use(SensorCapabilities(ecg: false, placement: .arm))
        let night = try await session.start(.sleep, name: "", plan: OvernightPlan(wakeAtMs: rig.clock.nowMs() + 8 * 3_600_000))
        let script: [FakeHeartSource.Step] = [.wait(ms: 960)] + posture(.lying, minutes: 3) + posture(.upright, minutes: 6)
        try await FakeHeartSource(clock: rig.clock, script: script).pump(into: session)
        #expect(try rig.events(night).filter { $0.kind == .posture }.isEmpty)
        #expect(await session.autoStopDue() == nil)
        #expect(try rig.count("motion") > 0, "motion itself is still stored")
    }
}
