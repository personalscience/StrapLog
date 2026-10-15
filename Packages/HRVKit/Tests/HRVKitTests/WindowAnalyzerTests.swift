import Testing
@testable import HRVKit

@Suite("WindowAnalyzer")
struct WindowAnalyzerTests {
    let analyzer = WindowAnalyzer()

    @Test("window with fewer than 60 raw beats is skipped")
    func tooFewRaw() {
        #expect(analyzer.features(of: [Double](repeating: 800, count: 59), center: 60) == nil)
    }

    @Test("window that drops below 60 beats after cleaning is skipped")
    func tooFewClean() {
        var rr = [Double](repeating: 800, count: 61)
        rr[10] = 100
        rr[20] = 2500
        #expect(analyzer.features(of: rr, center: 60) == nil)
    }

    @Test("empty input has no windows")
    func empty() {
        #expect(analyzer.features([]).isEmpty)
    }

    @Test("features carry counts, HR, and artifact rate")
    func basic() throws {
        var g = SeededGaussian(seed: 4)
        var rr = g.series(150).map { 1000 + 20 * $0 }
        rr[40] = 2000.5   // gated
        let f = try #require(analyzer.features(of: rr, center: 60))
        #expect(f.nRaw == 150)
        #expect(f.nBeats == 149)
        #expect(abs(f.artifactRate - 1.0 / 150) < 1e-12)
        #expect(abs(f.hrBpm - 60) < 1)
        #expect(f.alpha1 != nil)
        #expect(f.lnRMSSD != nil)
    }

    @Test("windows over a beat series use beat times")
    func overSeries() {
        var t = 0.0
        let beats = (0..<400).map { _ -> TimedSample<Double> in
            defer { t += 1 }
            return TimedSample(t: t, value: 1000)
        }
        let f = analyzer.features(beats)
        #expect(f.map(\.tCenter) == [60, 120, 180, 240, 300])   // arange(60, 340, 60)
        #expect(f.allSatisfy { $0.nRaw == 120 })
    }
}
