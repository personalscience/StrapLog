/// Running sums for one second of samples; `MotionReducer` keeps one open at a time.
struct MotionBucket: Sendable {
    let secondMs: Int64
    var n = 0
    var sumSq = 0.0
    var sx = 0.0, sy = 0.0, sz = 0.0

    func adding(_ s: AccSample) -> MotionBucket {
        var b = self
        let (x, y, z) = (Double(s.x), Double(s.y), Double(s.z))
        let dynamic = (x * x + y * y + z * z).squareRoot() - MotionReducer.gravityMg
        b.n += 1
        b.sumSq += dynamic * dynamic
        b.sx += x
        b.sy += y
        b.sz += z
        return b
    }

    func second(recordingId: Int64) -> MotionSecond {
        let k = Double(n)
        return MotionSecond(recordingId: recordingId, secondMs: secondMs, rmsMg: (sumSq / k).squareRoot().rounded(),
                            gxMg: (sx / k).rounded(), gyMg: (sy / k).rounded(), gzMg: (sz / k).rounded(), n: n)
    }
}
