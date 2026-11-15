/// One cosinor fit, `hr(τ) = mean + slope·τ + a·cos ωτ + b·sin ωτ`, over whole breaths.
public struct CosinorFit: Sendable, Equatable {
    /// Fitted HR at the window start (bpm); with the slope, the trend line.
    public let mean: Double
    /// HR drift over the window (bpm per second).
    public let slope: Double
    /// Peak-to-trough HR at the breathing rate, `2·√(a² + b²)` (bpm).
    public let swing: Double
    /// Share of detrended HR variance at the breathing rate, 0–1.
    public let sync: Double
    /// Where in the breath the fitted HR peaks, as a fraction from inhale start, in [0, 1).
    public let peakFraction: Double
    /// HR samples in the window.
    public let n: Int
}
