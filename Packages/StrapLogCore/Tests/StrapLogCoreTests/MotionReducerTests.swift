import Testing
@testable import StrapLogCore

/// `count` samples at 25 Hz from device time `fromNs`, all `(x, y, z)`, or per-index via `xyz`.
func acc(_ count: Int, fromNs: UInt64 = 0, xyz: (Int) -> (Int, Int, Int)) -> [AccSample] {
    (0..<count).map { i in
        let (x, y, z) = xyz(i)
        return AccSample(deviceNs: fromNs + UInt64(i) * 40_000_000, x: x, y: y, z: z)
    }
}

/// `flush()` that fails the test when nothing was pending (`#require` cannot wrap a mutating call).
func flushed(_ reducer: inout MotionReducer) throws -> MotionSecond {
    let second = reducer.flush()
    return try #require(second)
}

@Suite("MotionReducer")
struct MotionReducerTests {
    let t0: Int64 = 1_760_000_000_000

    /// Receipt time that places sample 0 of a 25 Hz batch of `count` exactly at `t0 + offsetMs`.
    func received(_ count: Int, offsetMs: Int64 = 0) -> Int64 { t0 + offsetMs + Int64(count - 1) * 40 }

    @Test("still and level: rms 0, gravity on z, n 25")
    func still() throws {
        var r = MotionReducer(recordingId: 1)
        #expect(r.add(receivedAtMs: received(25), samples: acc(25) { _ in (0, 0, 1000) }).isEmpty)
        let s = try flushed(&r)
        #expect(s == MotionSecond(recordingId: 1, secondMs: t0, rmsMg: 0, gxMg: 0, gyMg: 0, gzMg: 1000, n: 25))
        #expect(r.flush() == nil)
    }

    @Test("shaking ±200 mg along gravity: rms 200, mean gravity unchanged")
    func shaking() throws {
        var r = MotionReducer(recordingId: 1)
        _ = r.add(receivedAtMs: received(24), samples: acc(24) { i in (0, 0, i.isMultiple(of: 2) ? 1200 : 800) })
        let s = try flushed(&r)
        #expect(s.rmsMg == 200)
        #expect(s.gzMg == 1000)
    }

    @Test("tilted 45° and still: rms 0, gravity split between x and z")
    func tilted() throws {
        var r = MotionReducer(recordingId: 1)
        _ = r.add(receivedAtMs: received(25), samples: acc(25) { _ in (707, 0, 707) })
        let s = try flushed(&r)
        #expect(s.rmsMg == 0)
        #expect((s.gxMg, s.gyMg, s.gzMg) == (707, 0, 707))
    }

    @Test("50 samples from a second boundary fill exactly two seconds")
    func secondBoundary() throws {
        var r = MotionReducer(recordingId: 1)
        let done = r.add(receivedAtMs: received(50), samples: acc(50) { _ in (0, 0, 1000) })
        #expect(done.map(\.secondMs) == [t0])
        #expect(done.map(\.n) == [25])
        let last = try flushed(&r)
        #expect((last.secondMs, last.n) == (t0 + 1000, 25))
    }

    @Test("a second split across notifications is emitted once, when the next second starts")
    func splitAcrossBatches() {
        var r = MotionReducer(recordingId: 1)
        #expect(r.add(receivedAtMs: received(13), samples: acc(13) { _ in (0, 0, 1000) }).isEmpty)
        #expect(r.add(receivedAtMs: received(12, offsetMs: 520), samples: acc(12, fromNs: 520_000_000) { _ in (0, 0, 1000) }).isEmpty)
        let done = r.add(receivedAtMs: t0 + 1000, samples: acc(1, fromNs: 1_000_000_000) { _ in (0, 0, 1000) })
        #expect(done.map(\.n) == [25])
    }

    @Test("receipt jitter never moves time backwards: early samples clamp into the open second")
    func clamped() {
        var r = MotionReducer(recordingId: 1)
        // t0+940 … t0+1100: closes second t0 (2 samples) and opens t0+1000 (3).
        let first = r.add(receivedAtMs: t0 + 1100, samples: acc(5, fromNs: 0) { _ in (0, 0, 1000) })
        #expect(first.map(\.secondMs) == [t0])
        // Arrives early: by receipt it would start at t0+900, back in the closed second t0.
        #expect(r.add(receivedAtMs: t0 + 1060, samples: acc(5, fromNs: 200_000_000) { _ in (0, 0, 1000) }).isEmpty)
        #expect(r.flush()?.n == 8)
    }

    @Test("sample times come from device-clock offsets, or the nominal 40 ms when unusable")
    func times() {
        let spaced = [AccSample(deviceNs: 0, x: 0, y: 0, z: 0), AccSample(deviceNs: 30_000_000, x: 0, y: 0, z: 0),
                      AccSample(deviceNs: 75_000_000, x: 0, y: 0, z: 0)]
        #expect(MotionReducer.timesMs(receivedAtMs: 1000, samples: spaced) == [925, 955, 1000])
        let unset = acc(3) { _ in (0, 0, 0) }.map { AccSample(deviceNs: 0, x: $0.x, y: $0.y, z: $0.z) }
        #expect(MotionReducer.timesMs(receivedAtMs: 1000, samples: unset) == [920, 960, 1000])
        #expect(MotionReducer.timesMs(receivedAtMs: 1000, samples: []).isEmpty)
    }

    @Test("merging two halves of a second matches reducing it whole")
    func merge() throws {
        let samples = acc(25) { i in (i * 3, 0, 1000 + (i.isMultiple(of: 2) ? 90 : -90)) }
        var whole = MotionReducer(recordingId: 1)
        _ = whole.add(receivedAtMs: received(25), samples: samples)
        var a = MotionReducer(recordingId: 1), b = MotionReducer(recordingId: 1)
        _ = a.add(receivedAtMs: received(10), samples: Array(samples[..<10]))
        _ = b.add(receivedAtMs: received(25), samples: Array(samples[10...]))
        let merged = try flushed(&a).merged(with: try flushed(&b))
        let expected = try flushed(&whole)
        #expect(merged.n == expected.n)
        #expect(abs(merged.rmsMg - expected.rmsMg) <= 1)
        #expect(abs(merged.gxMg - expected.gxMg) <= 1)
        #expect(merged.gzMg == expected.gzMg)
    }
}
