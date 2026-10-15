/// Artifact removal identical to `clean_rr` in analyze_h10.py: a physiological
/// gate, then up to `iterations` passes of a centered rolling median that drops
/// beats deviating from it by more than `pctThresh`.
///
/// Non-finite input (NaN, ±inf) is treated like a gated beat: removed, never propagated.
public struct RRCleaner: Sendable {
    public var gateMs: ClosedRange<Double>
    public var pctThresh: Double
    public var iterations: Int

    public init(gateMs: ClosedRange<Double> = HRVDefaults.rrGateMs,
                pctThresh: Double = HRVDefaults.pctThresh,
                iterations: Int = HRVDefaults.cleanIterations) {
        self.gateMs = gateMs
        self.pctThresh = pctThresh
        self.iterations = iterations
    }

    public func clean(_ rrMs: [Double]) -> RRCleaning {
        var x: [Double?] = rrMs.map { $0.isFinite && gateMs.contains($0) ? $0 : nil }
        for _ in 0..<iterations {
            let medians = Self.centeredMedians(x)
            var flagged = false
            for i in x.indices {
                guard let v = x[i], let m = medians[i] else { continue }
                if abs(v - m) / m > pctThresh {
                    x[i] = nil
                    flagged = true
                }
            }
            if !flagged { break }
        }
        return RRCleaning(raw: rrMs, removedIndices: x.indices.filter { x[$0] == nil })
    }

    /// pandas `rolling(5, center=True, min_periods=3).median()`: missing values are
    /// skipped, edge windows are truncated, fewer than 3 present values gives nil.
    static func centeredMedians(_ x: [Double?]) -> [Double?] {
        let half = HRVDefaults.medianWindow / 2
        return x.indices.map { i in
            let lo = max(0, i - half), hi = min(x.count - 1, i + half)
            let present = x[lo...hi].compactMap { $0 }.sorted()
            guard present.count >= HRVDefaults.medianMinPeriods else { return nil }
            let mid = present.count / 2
            return present.count.isMultiple(of: 2) ? (present[mid - 1] + present[mid]) / 2 : present[mid]
        }
    }
}
