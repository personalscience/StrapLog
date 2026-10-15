import Testing
@testable import StrapLogCore

@Suite("BreathingPacer")
struct BreathingPacerTests {
    let pacer = BreathingPacer(breathsPerMinute: 6, startedAtMs: 1_000_000)

    func at(_ ms: Int64) -> BreathPhase { pacer.phase(atMs: 1_000_000 + ms) }

    @Test("6/min: 5 s in, 5 s out, repeating")
    func sixPerMinute() {
        #expect(pacer.periodMs == 10_000)
        #expect(at(0) == BreathPhase(inhaling: true, progress: 0, secondsLeft: 5))
        #expect(at(2_500) == BreathPhase(inhaling: true, progress: 0.5, secondsLeft: 2.5))
        #expect(at(5_000) == BreathPhase(inhaling: false, progress: 0, secondsLeft: 5))
        #expect(at(9_000).inhaling == false)
        #expect(at(10_000) == at(0))
        #expect(at(123_456) == at(3_456))
    }

    @Test("volume rises 0→1 on the in-breath and falls 1→0 on the out-breath")
    func volume() {
        #expect(at(0).volume == 0)
        #expect(abs(at(2_500).volume - 0.5) < 1e-12)
        #expect(at(5_000).volume == 1)
        #expect(abs(at(7_500).volume - 0.5) < 1e-12)
        #expect(at(1_000).volume < at(2_000).volume)
        #expect(at(6_000).volume > at(7_000).volume)
    }

    @Test("4.5/min breath lasts 13.3 s; times before the start read as the start")
    func slowRateAndClamp() {
        let slow = BreathingPacer(breathsPerMinute: 4.5, startedAtMs: 0)
        #expect(abs(slow.periodMs - 13_333.333) < 0.001)
        #expect(slow.phase(atMs: 6_000).inhaling)
        #expect(!slow.phase(atMs: 7_000).inhaling)
        #expect(pacer.phase(atMs: 0) == at(0))
    }

    @Test("note and rate range")
    func noteAndRange() {
        #expect(pacer.note == "6.0/min")
        #expect(BreathingPacer(breathsPerMinute: 4.5, startedAtMs: 0).note == "4.5/min")
        #expect(BreathingPacer.rates.contains(BreathingPacer.defaultRate))
        #expect(at(0).instruction == "Breathe in")
    }
}
