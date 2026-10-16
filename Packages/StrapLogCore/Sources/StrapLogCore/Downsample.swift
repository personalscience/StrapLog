/// Thins a time series for drawing without hiding spikes: splits the time range into
/// `buckets` equal slices and keeps each slice's minimum and maximum, in time order.
public enum Downsample {
    public static func minMax(_ points: [TrendPoint], buckets: Int) -> [TrendPoint] {
        guard buckets > 0, points.count > 2 * buckets,
              let first = points.first?.atMs, let last = points.last?.atMs, last > first
        else { return points }
        let width = Double(last - first) / Double(buckets)
        var out: [TrendPoint] = []
        out.reserveCapacity(2 * buckets)
        var lo = points[0], hi = points[0], bucket = 0
        func flush() {
            if lo.atMs <= hi.atMs { out.append(lo); if hi != lo { out.append(hi) } }
            else { out.append(hi); out.append(lo) }
        }
        for p in points.dropFirst() {
            let b = min(Int(Double(p.atMs - first) / width), buckets - 1)
            if b != bucket {
                flush()
                (lo, hi, bucket) = (p, p, b)
            } else {
                if p.value < lo.value { lo = p }
                if p.value > hi.value { hi = p }
            }
        }
        flush()
        return out
    }
}
