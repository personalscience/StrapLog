import Testing
@testable import StrapLogCore

/// `BreathingPacer`'s breath arithmetic: naming a breath, finding its start, sampling the wave.
@Suite("BreathingPacer breaths")
struct BreathingPacerBreathTests {
    /// 4.5/min gives a period of 13 333.3 ms, so every boundary is rounded; 1:2 and 4:6 move the turn.
    static let pacers: [BreathingPacer] = [
        BreathingPacer(breathsPerMinute: 6, startedAtMs: 1_000_000),
        BreathingPacer(breathsPerMinute: 4.5, ratio: .oneTwo, startedAtMs: 1_000_001),
        BreathingPacer(breathsPerMinute: 8, ratio: .fourSix, startedAtMs: 1_000_000),
        BreathingPacer(breathsPerMinute: 9.5, startedAtMs: 777),
    ]

    @Test("breath starts are the inhale turns nextTransition reports", arguments: pacers)
    func startsAgreeWithTransitions(pacer: BreathingPacer) {
        let inhales = pacer.transitions(afterMs: pacer.startedAtMs - 1, throughMs: pacer.startedAtMs + 300_000)
            .filter(\.inhaling).map(\.atMs)
        #expect(inhales == (0..<inhales.count).map(pacer.breathStartMs))
        #expect(inhales.count > 20)
    }

    @Test("a breath runs from its start up to the next one's", arguments: pacers)
    func indexAtBoundaries(pacer: BreathingPacer) {
        for k in -3...30 {
            let start = pacer.breathStartMs(k)
            #expect(pacer.breathIndex(atMs: start) == k)
            #expect(pacer.breathIndex(atMs: start - 1) == k - 1)
            #expect(pacer.breathIndex(atMs: pacer.breathStartMs(k + 1) - 1) == k)
        }
    }

    @Test("every time in a breath sits in that breath and its phase agrees", arguments: pacers)
    func indexAgreesWithPhase(pacer: BreathingPacer) {
        for t in stride(from: pacer.startedAtMs, through: pacer.startedAtMs + 60_000, by: 97) {
            let k = pacer.breathIndex(atMs: t)
            let start = pacer.breathStartMs(k)
            #expect(start <= t && t < pacer.breathStartMs(k + 1))
            // The exhale turn of breath k, as nextTransition reports it, splits in from out.
            let turn = pacer.nextTransition(afterMs: start)
            #expect(!turn.inhaling)
            // phase(atMs:) turns at the exact fractional ms, nextTransition and breathStartMs at the
            // rounded one: they can disagree within 1 ms of either turn.
            guard abs(t - turn.atMs) > 1, abs(t - start) > 1 else { continue }
            #expect(pacer.phase(atMs: t).inhaling == (t < turn.atMs))
        }
    }

    @Test("before the start: negative breaths, a whole period apart")
    func beforeStart() {
        let p = BreathingPacer(breathsPerMinute: 6, startedAtMs: 1_000_000)
        #expect(p.breathIndex(atMs: 999_999) == -1)
        #expect(p.breathIndex(atMs: 990_000) == -1)
        #expect(p.breathIndex(atMs: 989_999) == -2)
        #expect(p.breathStartMs(-1) == 990_000)
        #expect(p.breathIndex(atMs: 0) == -100)
    }

    @Test("volumes sample the wave every step, both ends included")
    func volumes() {
        let p = BreathingPacer(breathsPerMinute: 6, ratio: .fourSix, startedAtMs: 1_000)
        let v = p.volumes(fromMs: 1_000, throughMs: 21_000, stepMs: 250)
        #expect(v.count == 81)
        #expect(v.first?.atMs == 1_000 && v.last?.atMs == 21_000)
        #expect(v.allSatisfy { $0.value == p.phase(atMs: $0.atMs).volume })
        #expect(v.first?.value == 0)
        #expect(abs(v[16].value - 1) < 1e-12)   // 4 s in: the turn to out, lungs full
        #expect(p.volumes(fromMs: 2_000, throughMs: 1_000, stepMs: 250).isEmpty)
        #expect(p.volumes(fromMs: 1_000, throughMs: 1_100, stepMs: 250).map(\.atMs) == [1_000])
    }
}
