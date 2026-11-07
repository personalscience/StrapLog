import Testing
@testable import StrapLogCore

@MainActor
@Suite("PacerClock")
struct PacerClockTests {
    let clock = FakeClock()
    var t0: Int64 { 1_760_000_000_000 }

    func run(_ pacer: BreathingPacer, limit: Int, lateMs: [Int: Int64] = [:]) async -> (CueSpy, SleeperSpy, PacerClock) {
        let cues = CueSpy(clock: clock)
        let sleeper = SleeperSpy(clock: clock, limit: limit, lateMs: lateMs)
        let pacerClock = PacerClock(clock: clock, sleeper: sleeper, sink: cues)
        pacerClock.run(pacer)
        await sleeper.waitUntilParked()
        return (cues, sleeper, pacerClock)
    }

    @Test("6/min 1:1 cues the start, then each turn")
    func equal() async {
        let (cues, sleeper, pacerClock) = await run(BreathingPacer(breathsPerMinute: 6, startedAtMs: t0), limit: 2)
        #expect(cues.cues == [.init(atMs: t0, inhaling: true), .init(atMs: t0 + 5_000, inhaling: false),
                              .init(atMs: t0 + 10_000, inhaling: true)])
        #expect(sleeper.sleeps == [5_000, 5_000, 5_000])
        pacerClock.stop()
    }

    @Test("6/min 4:6 turns at 4 s and 10 s")
    func fourSix() async {
        let pacer = BreathingPacer(breathsPerMinute: 6, ratio: .fourSix, startedAtMs: t0)
        let (cues, _, pacerClock) = await run(pacer, limit: 2)
        #expect(cues.cues == [.init(atMs: t0, inhaling: true), .init(atMs: t0 + 4_000, inhaling: false),
                              .init(atMs: t0 + 10_000, inhaling: true)])
        #expect(cues.lengths == [4_000, 6_000, 4_000], "each cue carries its half's full length")
        pacerClock.stop()
    }

    @Test("started mid-breath, it cues the half it is in")
    func midBreath() async {
        clock.advance(byMs: 7_000)
        let (cues, sleeper, pacerClock) = await run(BreathingPacer(breathsPerMinute: 6, startedAtMs: t0), limit: 1)
        #expect(cues.cues == [.init(atMs: t0 + 7_000, inhaling: false), .init(atMs: t0 + 10_000, inhaling: true)])
        #expect(sleeper.sleeps.first == 3_000)
        pacerClock.stop()
    }

    @Test("a late wake cues once, for the half it landed in, and re-plans from there")
    func lateWake() async {
        // The first sleep aims for +5 s and overshoots to +17 s, in the second breath's exhale.
        let (cues, sleeper, pacerClock) = await run(BreathingPacer(breathsPerMinute: 6, startedAtMs: t0), limit: 2,
                                                    lateMs: [0: 12_000])
        #expect(cues.cues == [.init(atMs: t0, inhaling: true), .init(atMs: t0 + 17_000, inhaling: false),
                              .init(atMs: t0 + 20_000, inhaling: true)])
        #expect(sleeper.sleeps == [5_000, 3_000, 5_000])
        pacerClock.stop()
    }

    @Test("stop ends the cues and tells the sink once")
    func stop() async {
        let (cues, _, pacerClock) = await run(BreathingPacer(breathsPerMinute: 6, startedAtMs: t0), limit: 1)
        let before = cues.cues
        pacerClock.stop()
        pacerClock.stop()
        await Task.yield()
        clock.advance(byMs: 60_000)
        await Task.yield()
        #expect(cues.cues == before)
        #expect(cues.stops == 1)
    }

    @Test("stopping a clock that never ran says nothing")
    func stopIdle() {
        let cues = CueSpy(clock: clock)
        PacerClock(clock: clock, sleeper: SleeperSpy(clock: clock, limit: 0), sink: cues).stop()
        #expect(cues.stops == 0)
    }
}
