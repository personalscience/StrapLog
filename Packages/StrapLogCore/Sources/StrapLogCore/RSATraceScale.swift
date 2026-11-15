/// The HR range the RSA trace is drawn against: the trace's min and max, padded, whole bpm,
/// at least `minSpanBpm` tall so a flat trace does not fill the panel with noise.
public struct RSATraceScale: Sendable, Equatable {
    public static let minSpanBpm = 10.0
    /// Padding above and below, as a share of the trace's own span.
    public static let padFraction = 0.1

    public let lowBpm: Double
    public let highBpm: Double

    /// Nil for an empty trace.
    public init?(_ trace: [TrendPoint]) {
        guard let low = trace.map(\.value).min(), let high = trace.map(\.value).max() else { return nil }
        let pad = (high - low) * Self.padFraction
        var (lo, hi) = ((low - pad).rounded(.down), (high + pad).rounded(.up))
        if hi - lo < Self.minSpanBpm {
            let widen = (Self.minSpanBpm - (hi - lo)) / 2
            (lo, hi) = ((lo - widen).rounded(.down), (hi + widen).rounded(.up))
        }
        lowBpm = lo
        highBpm = hi
    }

    /// Where `bpm` sits, 0 at `lowBpm` to 1 at `highBpm` (outside for values outside).
    public func fraction(_ bpm: Double) -> Double {
        (bpm - lowBpm) / (highBpm - lowBpm)
    }
}
