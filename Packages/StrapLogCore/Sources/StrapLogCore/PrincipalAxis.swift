/// The direction along which a 3-axis signal varies most, tracked live: an exponentially
/// forgetting covariance and one power-iteration step per sample. Power iteration on a
/// covariance never turns the axis through more than 90° in a step, so its sign stays put and
/// a projection onto it keeps its meaning (what `BreathTracker`'s sign calibration relies on).
struct PrincipalAxis: Sendable {
    let tauMs: Double
    /// Covariance rows.
    private var c0 = SIMD3<Double>(), c1 = SIMD3<Double>(), c2 = SIMD3<Double>()
    /// Starts off every axis, so it converges on any dominant one.
    private(set) var axis = SIMD3<Double>(1, 1, 1) / 3.0.squareRoot()

    init(tauMs: Double) {
        self.tauMs = tauMs
    }

    /// Adds a zero-mean sample; returns its projection onto the updated axis.
    mutating func add(_ v: SIMD3<Double>, dtMs: Double) -> Double {
        let a = dtMs / (tauMs + dtMs)
        c0 = c0 * (1 - a) + v * (v.x * a)
        c1 = c1 * (1 - a) + v * (v.y * a)
        c2 = c2 * (1 - a) + v * (v.z * a)
        let w = SIMD3((c0 * axis).sum(), (c1 * axis).sum(), (c2 * axis).sum())
        let length = (w * w).sum().squareRoot()
        if length > 1e-9 { axis = w / length }
        return (v * axis).sum()
    }
}
