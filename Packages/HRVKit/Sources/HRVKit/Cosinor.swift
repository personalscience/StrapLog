import Foundation

/// Least-squares fit of HR to a sinusoid at the known breath period plus a linear
/// trend, on unevenly spaced samples. The trend absorbs drift; fitting whole breaths
/// keeps the sine terms orthogonal to the mean. Mirrors `cosinor` in gen_rsa_fixture.py.
public enum Cosinor {
    /// Fits the samples with `fromS ≤ t < fromS + breaths·periodS`, `τ = t − fromS`.
    /// Nil with fewer than `minSamplesPerFitBreath` samples per breath, holes covering
    /// more than `maxHoleFraction` of the window, or no variance to explain.
    public static func fit(_ samples: some Collection<TimedSample<Double>>, periodS: Double, fromS: Double,
                           breaths: Int = RSADefaults.windowBreaths) -> CosinorFit? {
        precondition(periodS > 0 && breaths > 0, "a window is one or more whole breaths")
        let toS = fromS + Double(breaths) * periodS
        let inWindow = samples.filter { fromS <= $0.t && $0.t < toS }.sorted { $0.t < $1.t }
        guard inWindow.count >= RSADefaults.minSamplesPerFitBreath * breaths,
              Gaps.holeSeconds(inWindow.map(\.t), fromS: fromS, toS: toS)
                <= RSADefaults.maxHoleFraction * (toS - fromS)
        else { return nil }

        let omega = 2 * Double.pi / periodS
        let rows = inWindow.map { s -> [Double] in
            let tau = s.t - fromS
            return [1, tau, cos(omega * tau), sin(omega * tau)]
        }
        let y = inWindow.map(\.value)
        guard let full = LeastSquares.solve(rows, y),
              let trend = LeastSquares.solve(rows.map { Array($0.prefix(2)) }, y)
        else { return nil }
        let ssTrend = LeastSquares.residualSquares(rows.map { Array($0.prefix(2)) }, y, trend)
        guard ssTrend > 0 else { return nil }
        let ssFull = LeastSquares.residualSquares(rows, y, full)

        let (a, b) = (full[2], full[3])
        let turn = atan2(b, a) / (2 * Double.pi)
        return CosinorFit(mean: full[0], slope: full[1], swing: 2 * (a * a + b * b).squareRoot(),
                          sync: 1 - ssFull / ssTrend, peakFraction: turn - turn.rounded(.down),
                          n: inWindow.count)
    }
}
