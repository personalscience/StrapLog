import Foundation

/// Time-domain HRV on an already-cleaned RR series (ms). Every function returns
/// nil when the input is too short to define the metric, never NaN.
public enum TimeDomain {
    /// Root mean square of successive differences. Needs ≥ 2 beats.
    public static func rmssd(_ rr: [Double]) -> Double? {
        guard rr.count >= 2 else { return nil }
        let sq = zip(rr.dropFirst(), rr).map { ($0 - $1) * ($0 - $1) }
        return (sq.reduce(0, +) / Double(sq.count)).squareRoot()
    }

    /// Natural log of RMSSD; nil when RMSSD is undefined or zero.
    public static func lnRMSSD(_ rr: [Double]) -> Double? {
        guard let r = rmssd(rr), r > 0 else { return nil }
        return log(r)
    }

    /// Sample standard deviation (ddof = 1, the Kubios convention). Needs ≥ 2 beats.
    public static func sdnn(_ rr: [Double]) -> Double? {
        guard rr.count >= 2, let m = mean(rr) else { return nil }
        let ss = rr.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (ss / Double(rr.count - 1)).squareRoot()
    }

    /// 60000 / mean RR, as analyze_h10 computes window HR.
    public static func meanHR(_ rr: [Double]) -> Double? {
        guard let m = mean(rr), m > 0 else { return nil }
        return 60000 / m
    }

    static func mean(_ x: [Double]) -> Double? {
        x.isEmpty ? nil : x.reduce(0, +) / Double(x.count)
    }
}
