/// Running sums for one second of samples; `MotionReducer` keeps one open at a time.
struct MotionBucket: Sendable {
    let secondMs: Int64
    var n = 0
    /// Sums of |a| and |a|², for its spread around the second's own mean.
    var sumMag = 0.0
    var sumMagSq = 0.0
    var sx = 0.0, sy = 0.0, sz = 0.0

    func adding(_ s: AccSample) -> MotionBucket {
        var b = self
        let (x, y, z) = (Double(s.x), Double(s.y), Double(s.z))
        let mag = (x * x + y * y + z * z).squareRoot()
        b.n += 1
        b.sumMag += mag
        b.sumMagSq += mag * mag
        b.sx += x
        b.sy += y
        b.sz += z
        return b
    }

    func second(recordingId: Int64) -> MotionSecond {
        let k = Double(n)
        let mean = sumMag / k
        let spread = max(0, sumMagSq / k - mean * mean).squareRoot()
        return MotionSecond(recordingId: recordingId, secondMs: secondMs, rmsMg: spread.rounded(),
                            gxMg: (sx / k).rounded(), gyMg: (sy / k).rounded(), gzMg: (sz / k).rounded(), n: n)
    }
}
