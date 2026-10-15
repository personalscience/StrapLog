import HRVKit
import Testing
@testable import StrapLogCore

@Suite("LiveMetrics")
struct LiveMetricsTests {
    static let origin: Int64 = 1_760_000_000_000

    @Test("fed beat by beat, equals the WindowAnalyzer batch at every stride", arguments: RRFixture.names)
    func parity(name: String) throws {
        let fx = try RRFixture.load(name)
        let analyzer = WindowAnalyzer()
        let batch = analyzer.features(zip(fx.t_rel_s, fx.rr_ms).map { TimedSample(t: $0, value: $1) })
        let ends = fx.endTimesMs(originMs: Self.origin)

        var live = LiveMetrics()
        var strides = 0
        for (end, rr) in zip(ends, fx.rr_ms) {
            let before = live.closedWindows
            live.add(tEndMs: end, rrMs: rr)
            guard live.closedWindows != before else { continue }
            strides += 1
            let closedUpTo = analyzer.window.center(ofWindow: live.closedWindows - 1)
            #expect(live.windows == batch.filter { $0.tCenter <= closedUpTo })
            #expect(live.latest == live.windows.last.flatMap { $0.tCenter == closedUpTo ? $0 : nil })
        }
        #expect(strides > 0)
        // The batch may hold one last window that ends within 1 s after the final beat.
        let unclosed = batch.dropFirst(live.windows.count)
        #expect(unclosed.count <= 1)
        #expect(unclosed.allSatisfy { $0.tCenter + analyzer.window.width / 2 > fx.t_rel_s.last! })
    }

    @Test("a window with fewer than 60 beats yields no features")
    func refusesShortWindows() {
        var live = LiveMetrics()
        for i in 0..<59 { live.add(tEndMs: Self.origin + Int64(i) * 2000, rrMs: 2000) }   // 59 beats in 0–118 s
        live.add(tEndMs: Self.origin + 120_000, rrMs: 1000)
        #expect(live.closedWindows == 1)
        #expect(live.latest == nil)
        #expect(live.windows.isEmpty)
    }

    @Test("a long silence closes every window it spans, all empty")
    func gapClosesWindows() {
        var live = LiveMetrics()
        for i in 0..<200 { live.add(tEndMs: Self.origin + Int64(i) * 1000, rrMs: 1000 + Double(i % 7)) }
        #expect(live.closedWindows == 2)          // windows ending at 120 s and 180 s
        #expect(live.latest != nil)
        #expect(live.latestWindowEndMs == Self.origin + 180_000)
        live.add(tEndMs: Self.origin + 900_000, rrMs: 1000)
        #expect(live.closedWindows == 14)         // last one ends at 900 s
        #expect(live.latest == nil)
        #expect(live.windows.count == 3)          // plus 120–240 s, which holds beats 120–199
    }

    @Test("the tachogram keeps the last 5 minutes of raw RR")
    func tachogramSpan() {
        var live = LiveMetrics()
        for i in 0...600 { live.add(tEndMs: Self.origin + Int64(i) * 1000, rrMs: 1000) }
        #expect(live.tachogram.first?.atMs == Self.origin + 300_000)
        #expect(live.tachogram.last?.atMs == Self.origin + 600_000)
        #expect(live.tachogram.count == 301)
    }
}
