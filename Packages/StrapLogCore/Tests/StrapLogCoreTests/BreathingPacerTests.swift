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

    @Test("4:6 at 6/min: 4 s in, 6 s out")
    func fourSixAtSix() {
        let p = BreathingPacer(breathsPerMinute: 6, ratio: .fourSix, startedAtMs: 0)
        #expect(p.inhaleMs == 4_000 && p.exhaleMs == 6_000)
        #expect(p.phase(atMs: 0) == BreathPhase(inhaling: true, progress: 0, secondsLeft: 4))
        #expect(p.phase(atMs: 4_000) == BreathPhase(inhaling: false, progress: 0, secondsLeft: 6))
        #expect(p.phase(atMs: 10_000) == p.phase(atMs: 0))
    }

    @Test("1:2 at 6/min: inhale a third of the breath")
    func oneTwoAtSix() {
        let p = BreathingPacer(breathsPerMinute: 6, ratio: .oneTwo, startedAtMs: 0)
        #expect(abs(p.inhaleMs - 10_000.0 / 3) < 1e-9)
        #expect(p.phase(atMs: 3_000).inhaling)
        #expect(!p.phase(atMs: 3_400).inhaling)
        #expect(p.phase(atMs: 10_000) == p.phase(atMs: 0))
        #expect(p.note == "6.0/min in3.3 out6.7 t0=0")
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
        #expect(pacer.rateText == "6.0/min")
        #expect(pacer.note == "6.0/min in5.0 out5.0 t0=1000000")
        #expect(BreathingPacer(breathsPerMinute: 4.5, startedAtMs: 0).note == "4.5/min in6.7 out6.7 t0=0")
        #expect(BreathingPacer.rates.contains(BreathingPacer.defaultRate))
        #expect(at(0).instruction == "Breathe in")
    }

    @Test("a note parses back to itself at every rate and ratio")
    func stampRoundTrip() throws {
        for ratio in BreathRatio.allCases {
            var rate = BreathingPacer.rates.lowerBound
            while rate <= BreathingPacer.rates.upperBound {
                let note = BreathingPacer(breathsPerMinute: rate, ratio: ratio, startedAtMs: 1_762_070_400_000).note
                let stamp = try #require(PacerStamp(note: note))
                #expect(stamp.note == note)
                #expect(stamp.breathsPerMinute == rate)
                #expect(stamp.t0Ms == 1_762_070_400_000)
                rate += BreathingPacer.rateStep
            }
        }
    }

    @Test("a pre-1.2 note has equal halves and no origin")
    func legacyStamp() throws {
        let stamp = try #require(PacerStamp(note: "5.0/min"))
        #expect(stamp == PacerStamp(breathsPerMinute: 5, inhaleS: 6, exhaleS: 6, t0Ms: nil))
    }

    @Test("notes outside the grammar do not parse", arguments: [
        "", "/min", "0/min", "6.0", "6.0/min t0=", "6.0/min out5.0 in5.0", "6.0/min t0=1 in5.0", "x 6.0/min",
    ])
    func badStamp(note: String) {
        #expect(PacerStamp(note: note) == nil)
    }

    @Test("nextTransition walks the turns, whole ms, none skipped or repeated")
    func nextTransition() {
        let next = pacer.nextTransition(afterMs: 1_000_000)
        #expect(next.atMs == 1_005_000 && !next.inhaling)
        let after = pacer.nextTransition(afterMs: 1_005_000)
        #expect(after.atMs == 1_010_000 && after.inhaling)
        let early = pacer.nextTransition(afterMs: 0)
        #expect(early.atMs == 1_000_000 && early.inhaling)
    }

    @Test("turns alternate at every rate and ratio, even where the period is not whole ms", arguments: BreathRatio.allCases)
    func turnsAlternate(ratio: BreathRatio) {
        var rate = BreathingPacer.rates.lowerBound
        while rate <= BreathingPacer.rates.upperBound {
            let pacer = BreathingPacer(breathsPerMinute: rate, ratio: ratio, startedAtMs: 1_000)
            var at: Int64 = 1_000
            var inhaling = true
            for _ in 0..<2_000 {
                let next = pacer.nextTransition(afterMs: at)
                #expect(next.inhaling != inhaling, "\(rate) \(ratio) after \(at)")
                #expect(next.atMs > at + 1_000)
                #expect(abs(Double(next.atMs) - (Double(at) + (inhaling ? pacer.inhaleMs : pacer.exhaleMs))) <= 1)
                at = next.atMs
                inhaling = next.inhaling
            }
            rate += BreathingPacer.rateStep
        }
    }
}
