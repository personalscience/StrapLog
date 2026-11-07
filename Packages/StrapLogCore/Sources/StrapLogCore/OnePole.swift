/// A first-order low-pass filter on a 3-axis signal with uneven sample spacing: the coefficient
/// is worked out from each step's `dtMs`, so 25 Hz strap batches and 1 Hz test fixtures filter alike.
struct OnePole: Sendable {
    /// Time constant, `1 / (2π · cutoff)`.
    let tauMs: Double
    private(set) var value: SIMD3<Double>?

    init(cutoffHz: Double) {
        tauMs = 1000 / (2 * .pi * cutoffHz)
    }

    /// The filtered value after `x`; the first sample passes through unchanged.
    mutating func step(_ x: SIMD3<Double>, dtMs: Double) -> SIMD3<Double> {
        guard let prev = value else { value = x; return x }
        let next = prev + (x - prev) * (dtMs / (tauMs + dtMs))
        value = next
        return next
    }

    /// Restarts from `x`, as if it were the first sample.
    mutating func snap(to x: SIMD3<Double>?) {
        value = x
    }
}
