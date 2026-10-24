import HRVKit
import Testing
@testable import StrapLogCore

@Suite("LiveMetrics")
struct LiveMetricsTests {
    static let origin: Int64 = 1_760_000_000_000
    /// The skills' 60 s stride, so window counts below are easy to check by hand.
    static func batchStride() -> LiveMetrics { LiveMetrics(analyzer: WindowAnalyzer()) }

    @Test("fed beat by beat, equals the WindowAnalyzer batch at every stride", arguments: RRFixture.names)
    func parity(name: String) throws {
        let fx = try RRFixture.load(name)
        let analyzer = LiveMetrics().analyzer
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

    @Test("every third 20 s window is one of the skills' 60 s windows", arguments: RRFixture.names)
    func everyThirdIsBatch(name: String) throws {
        let fx = try RRFixture.load(name)
        let batch = WindowAnalyzer().features(zip(fx.t_rel_s, fx.rr_ms).map { TimedSample(t: $0, value: $1) })
        var live = LiveMetrics()
        for (end, rr) in zip(fx.endTimesMs(originMs: Self.origin), fx.rr_ms) { live.add(tEndMs: end, rrMs: rr) }
        let aligned = live.windows.filter { ($0.tCenter - 60).truncatingRemainder(dividingBy: 60) == 0 }
        #expect(!aligned.isEmpty)
        #expect(aligned == Array(batch.prefix(aligned.count)))
    }

    @Test("lowest window HR equals SessionSummary.lowestHR on the same beats", arguments: RRFixture.names)
    func lowestMatchesSummary(name: String) throws {
        let fx = try RRFixture.load(name)
        let ends = fx.endTimesMs(originMs: Self.origin)
        var live = LiveMetrics()
        for (end, rr) in zip(ends, fx.rr_ms) { live.add(tEndMs: end, rrMs: rr) }
        // Close any window still open at the last beat, without adding a window with features.
        live.add(tEndMs: ends.last! + 600_000, rrMs: 1000)
        let summary = SessionSummary(rrMs: fx.rr_ms, tEndMs: ends, durationMs: nil, coverage: 1)
        #expect(live.lowestWindowHR != nil)
        #expect(live.lowestWindowHR == summary.lowestHR)
    }

    @Test("lowest window HR is the running minimum of the 60 s-stride windows")
    func lowestIsRunningMinimum() throws {
        let fx = try RRFixture.load(RRFixture.names[0])
        var live = LiveMetrics()
        #expect(live.lowestWindowHR == nil)
        var previous: Double?
        for (end, rr) in zip(fx.endTimesMs(originMs: Self.origin), fx.rr_ms) {
            live.add(tEndMs: end, rrMs: rr)
            let aligned = live.windows.filter { ($0.tCenter - 60).truncatingRemainder(dividingBy: 60) == 0 }
            #expect(live.lowestWindowHR == aligned.map(\.hrBpm).min())
            let first = aligned.first { $0.hrBpm == live.lowestWindowHR }
            #expect(live.lowestWindow?.atMs == first.map { Self.origin + Int64($0.tCenter * 1000) },
                    "stamped at the centre of the earliest lowest window")
            if let previous { #expect(live.lowestWindowHR! <= previous) }
            previous = live.lowestWindowHR
        }
    }

    @Test("α1 history is stamped at each window's end")
    func alpha1AtWindowEnd() throws {
        let fx = try RRFixture.load(RRFixture.names[0])
        var live = LiveMetrics()
        for (end, rr) in zip(fx.endTimesMs(originMs: Self.origin), fx.rr_ms) { live.add(tEndMs: end, rrMs: rr) }
        let first = try #require(live.windows.first { $0.alpha1 != nil })
        #expect(live.alpha1History.first == TrendPoint(atMs: Self.origin + Int64((first.tCenter + 60) * 1000),
                                                       value: first.alpha1!))
        #expect(live.alpha1History.count == live.windows.filter { $0.alpha1 != nil }.count)
    }

    @Test("lastAlpha1 is the newest α1 and outlives windows with too few beats")
    func lastAlpha1() throws {
        let fx = try RRFixture.load(RRFixture.names[0])
        var live = LiveMetrics()
        #expect(live.lastAlpha1 == nil)
        let ends = fx.endTimesMs(originMs: Self.origin)
        for (end, rr) in zip(ends, fx.rr_ms) { live.add(tEndMs: end, rrMs: rr) }
        #expect(live.lastAlpha1 == live.alpha1History.last)
        live.add(tEndMs: ends.last! + 600_000, rrMs: 1000)   // ten silent minutes
        #expect(live.latest == nil)
        #expect(live.lastAlpha1 != nil)
        #expect(live.lastAlpha1 == live.alpha1History.last)
    }

    @Test("a window with fewer than 60 beats yields no features")
    func refusesShortWindows() {
        var live = Self.batchStride()
        for i in 0..<59 { live.add(tEndMs: Self.origin + Int64(i) * 2000, rrMs: 2000) }   // 59 beats in 0–118 s
        live.add(tEndMs: Self.origin + 120_000, rrMs: 1000)
        #expect(live.closedWindows == 1)
        #expect(live.latest == nil)
        #expect(live.windows.isEmpty)
    }

    @Test("a long silence closes every window it spans, all empty")
    func gapClosesWindows() {
        var live = Self.batchStride()
        for i in 0..<200 { live.add(tEndMs: Self.origin + Int64(i) * 1000, rrMs: 1000 + Double(i % 7)) }
        #expect(live.closedWindows == 2)          // windows ending at 120 s and 180 s
        #expect(live.latest != nil)
        #expect(live.latestWindowEndMs == Self.origin + 180_000)
        live.add(tEndMs: Self.origin + 900_000, rrMs: 1000)
        #expect(live.closedWindows == 14)         // last one ends at 900 s
        #expect(live.latest == nil)
        #expect(live.windows.count == 3)          // plus 120–240 s, which holds beats 120–199
    }

    @Test("RR history keeps the last historySpanMs, and HR mirrors it")
    func historySpan() {
        var live = LiveMetrics(historySpanMs: 300_000)
        for i in 0...600 { live.add(tEndMs: Self.origin + Int64(i) * 1000, rrMs: 1000) }
        #expect(live.rrHistory.first?.atMs == Self.origin + 300_000)
        #expect(live.rrHistory.last?.atMs == Self.origin + 600_000)
        #expect(live.rrHistory.count == 301)
        #expect(live.hrHistory.count == 301)
        #expect(live.hrHistory.allSatisfy { $0.value == 60 })
    }
}
