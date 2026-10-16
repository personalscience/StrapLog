import Testing
@testable import StrapLogCore

@Suite("Downsample")
struct DownsampleTests {
    @Test("short series pass through unchanged")
    func passThrough() {
        let pts = (0..<10).map { TrendPoint(atMs: Int64($0) * 1000, value: Double($0)) }
        #expect(Downsample.minMax(pts, buckets: 5) == pts)
    }

    @Test("keeps at most two points per bucket, in time order, including every extreme")
    func keepsExtremes() {
        var pts = (0..<10_000).map { TrendPoint(atMs: Int64($0) * 1000, value: 1000 + Double($0 % 13)) }
        pts[4321] = TrendPoint(atMs: 4_321_000, value: 300)     // a dropped-beat spike
        pts[8765] = TrendPoint(atMs: 8_765_000, value: 2000)
        let out = Downsample.minMax(pts, buckets: 200)
        #expect(out.count <= 400)
        #expect(out.contains(pts[4321]))
        #expect(out.contains(pts[8765]))
        #expect(zip(out, out.dropFirst()).allSatisfy { $0.atMs < $1.atMs })
        #expect(out.map(\.value).min() == 300)
        #expect(out.map(\.value).max() == 2000)
    }
}
