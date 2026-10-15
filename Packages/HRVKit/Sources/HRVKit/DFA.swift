import Foundation

/// Detrended fluctuation analysis, short-term exponent α1, identical in method to
/// `dfa_alpha1` in analyze_h10.py: integrate the mean-removed series, split it into
/// non-overlapping boxes of each scale, remove a least-squares line per box, and
/// fit log F(n) against log n.
public enum DFA {
    /// α1 over `scales`; nil when the series is shorter than 4 × the largest scale,
    /// or fewer than 4 scales yield a positive fluctuation.
    public static func alpha1(_ rr: [Double], scales: ClosedRange<Int> = HRVDefaults.dfaScales) -> Double? {
        let total = rr.count
        guard total >= scales.upperBound * 4, let mean = TimeDomain.mean(rr) else { return nil }

        var y = [Double](repeating: 0, count: total)
        var acc = 0.0
        for i in 0..<total {
            acc += rr[i] - mean
            y[i] = acc
        }

        var logN: [Double] = [], logF: [Double] = []
        for n in scales {
            guard let f = fluctuation(y, boxSize: n), f > 0, f.isFinite else { continue }
            logN.append(log(Double(n)))
            logF.append(log(f))
        }
        guard logN.count >= 4 else { return nil }
        return slope(x: logN, y: logF)
    }

    /// RMS residual after per-box linear detrending; nil when fewer than 4 boxes fit.
    static func fluctuation(_ y: [Double], boxSize n: Int) -> Double? {
        let boxes = y.count / n
        guard boxes >= 4 else { return nil }
        let xMean = Double(n - 1) / 2
        var xVar = 0.0
        for k in 0..<n { xVar += (Double(k) - xMean) * (Double(k) - xMean) }

        var sumSq = 0.0
        for b in 0..<boxes {
            let seg = y[(b * n)..<(b * n + n)]
            let segMean = seg.reduce(0, +) / Double(n)
            var cov = 0.0
            for (k, v) in seg.enumerated() { cov += (v - segMean) * (Double(k) - xMean) }
            let beta = cov / xVar
            let intercept = segMean - beta * xMean
            for (k, v) in seg.enumerated() {
                let r = v - (beta * Double(k) + intercept)
                sumSq += r * r
            }
        }
        return (sumSq / Double(boxes * n)).squareRoot()
    }

    /// Ordinary least-squares slope.
    static func slope(x: [Double], y: [Double]) -> Double {
        let mx = x.reduce(0, +) / Double(x.count)
        let my = y.reduce(0, +) / Double(y.count)
        var num = 0.0, den = 0.0
        for (a, b) in zip(x, y) {
            num += (a - mx) * (b - my)
            den += (a - mx) * (a - mx)
        }
        return num / den
    }
}
