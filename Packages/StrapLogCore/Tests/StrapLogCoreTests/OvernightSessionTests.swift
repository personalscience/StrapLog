import Foundation
import GRDB
import Testing
@testable import StrapLogCore

/// `minutes` of one-batch-per-second motion in `posture`, starting 960 ms into a second
/// so each batch fills one second (see `motion()`).
func posture(_ posture: Posture, minutes: Int) -> [FakeHeartSource.Step] {
    let (x, y, z) = posture == .upright ? (-880, 80, 412) : (-363, -909, 207)
    let batch = FakeHeartSource.Step.emit(.motion(samples: acc(25) { _ in (x, y, z) }))
    return Array(repeating: [batch, .wait(ms: 1000)], count: minutes * 60).flatMap { $0 }
}

@Suite("Overnight RecordingSession")
struct OvernightSessionTests {
    let rig: TestRig
    let session: RecordingSession

    init() throws {
        rig = try TestRig()
        session = RecordingSession(database: rig.database, clock: rig.clock, uprightStopMs: 5 * 60_000)
    }

    func play(_ script: [FakeHeartSource.Step]) async throws {
        try await FakeHeartSource(clock: rig.clock, script: [.wait(ms: 960)] + script).pump(into: session)
    }

    func postureNotes(_ id: Int64) throws -> [String?] {
        try rig.events(id).filter { $0.kind == .posture }.map(\.note)
    }

    @Test("sleep keeps its plan in context and logs posture changes; other does neither")
    func postureEvents() async throws {
        let wake = rig.clock.nowMs() + 8 * 3_600_000
        let night = try await session.start(.sleep, name: "", plan: OvernightPlan(wakeAtMs: wake))
        #expect(try rig.recording(night)?.context == OvernightPlan(wakeAtMs: wake).contextJSON)
        try await play(posture(.upright, minutes: 2) + posture(.lying, minutes: 3) + posture(.upright, minutes: 2))
        #expect(try postureNotes(night) == ["upright", "lying", "upright"])
        try await session.stop()

        let lift = try await session.start(.other, name: "", plan: OvernightPlan(wakeAtMs: wake))
        try await play(posture(.upright, minutes: 2) + posture(.lying, minutes: 2))
        #expect(try rig.recording(lift)?.context == nil)
        #expect(try postureNotes(lift).isEmpty)
        #expect(await session.autoStopDue() == nil)
    }

    @Test("upright for uprightStopMs after lying down is due; a bathroom trip and sitting up in bed are not")
    func uprightStop() async throws {
        try await session.start(.sleep, name: "")
        try await play(posture(.upright, minutes: 10))
        #expect(await session.autoStopDue() == nil, "reading in bed before lying down")
        try await play(posture(.lying, minutes: 30) + posture(.upright, minutes: 3) + posture(.lying, minutes: 30))
        #expect(await session.autoStopDue() == nil, "bathroom trip")
        try await play(posture(.upright, minutes: 5))
        #expect(await session.autoStopDue() == .upright)
    }

    @Test("the wake time is due once reached, and the stop is noted with the reason")
    func wakeTime() async throws {
        let id = try await session.start(.sleep, name: "", plan: OvernightPlan(wakeAtMs: rig.clock.nowMs() + 60_000))
        rig.clock.advance(byMs: 59_999)
        #expect(await session.autoStopDue() == nil)
        rig.clock.advance(byMs: 1)
        #expect(await session.autoStopDue() == .wakeTime)
        try await session.stop(because: .wakeTime)
        #expect(try rig.events(id).last?.note == "wake_time")
        #expect(await session.autoStopDue() == nil, "idle")
    }

    @Test("a relaunch mid-night restores the plan from context")
    func resume() async throws {
        try await session.start(.sleep, name: "", plan: OvernightPlan(wakeAtMs: rig.clock.nowMs() + 3_600_000))
        rig.clock.advance(byMs: 3_600_000)
        let relaunched = rig.relaunched()
        try await relaunched.resumeIfOpen()
        #expect(await relaunched.autoStopDue() == .wakeTime)
    }
}
