import Testing
@testable import StrapLogCore

@Suite("BeatTiming")
struct BeatTimingTests {
    @Test("rr_1024 → ms is exact", arguments: [
        (1024, 1000.0), (1, 0.9765625), (819, 799.8046875), (0, 0.0), (2048, 2000.0), (333, 325.1953125),
    ])
    func conversion(rr: Int, ms: Double) {
        #expect(BeatTiming.ms(fromRR1024: rr) == ms)
        #expect(BeatTiming.ms(fromRR1024: rr) * 1024 / 1000 == Double(rr))
    }

    @Test("no RRs → no end times")
    func none() {
        #expect(BeatTiming.endTimesMs(receivedAtMs: 10_000, rr1024: []) == [])
    }

    @Test("one RR ends at receipt")
    func one() {
        #expect(BeatTiming.endTimesMs(receivedAtMs: 10_000, rr1024: [1024]) == [10_000])
    }

    @Test("two RRs: first ends one later-RR earlier")
    func two() {
        #expect(BeatTiming.endTimesMs(receivedAtMs: 10_000, rr1024: [800, 1024]) == [9_000, 10_000])
    }

    @Test("three RRs: cumulative sum of later RRs, rounded once")
    func three() {
        // later sums: 0, 700 (683.59 ms → 684), 1300 (1269.53 → 1270)
        #expect(BeatTiming.endTimesMs(receivedAtMs: 10_000, rr1024: [500, 600, 700]) == [8_730, 9_316, 10_000])
    }
}
