import Testing
@testable import HRVKit

@Suite("SlidingWindow")
struct SlidingWindowTests {
    let window = SlidingWindow(width: 120, stride: 60)

    @Test("centers follow numpy arange(w/2, tEnd - w/2 + 1, stride)")
    func centers() {
        // arange(60, 181, 60) -> [60, 120, 180]
        #expect(window.centers(tEnd: 240) == [60, 120, 180])
        // arange(60, 180.5, 60) -> [60, 120, 180]
        #expect(window.centers(tEnd: 239.5) == [60, 120, 180])
        // arange(60, 61, 60) -> [60]
        #expect(window.centers(tEnd: 120) == [60])
        #expect(window.centers(tEnd: 100) == [])
    }

    @Test("membership is half-open [lo, hi)")
    func halfOpen() {
        let samples = [0.0, 59.9, 60, 119.999, 120, 180].map { TimedSample(t: $0, value: $0) }
        let w = window.windows(over: samples)
        #expect(w.map(\.center) == [60, 120])
        #expect(w[0].values == [0, 59.9, 60, 119.999])
        #expect(w[1].values == [60, 119.999, 120])
    }

    @Test("empty input has no windows")
    func empty() {
        #expect(window.windows(over: [TimedSample<Double>]()).isEmpty)
    }

    @Test("generic over the sample value")
    func generic() {
        let samples = (0...200).map { TimedSample(t: Double($0), value: "b\($0)") }
        let w = window.windows(over: samples)
        #expect(w.count == 2)
        #expect(w[0].values.first == "b0")
        #expect(w[0].values.count == 120)
    }
}
