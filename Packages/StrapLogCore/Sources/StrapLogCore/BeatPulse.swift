import Foundation

/// The heartbeat as a pulse that fades between beats, carried forward from the last R peak the
/// ECG showed at its R-R interval, so it lands on beats the strap has not yet sent (ECG arrives
/// half a second or so late). Fades out once no beat has been seen for `staleAfterMs`.
public struct BeatPulse: Sendable, Equatable {
    /// The last detected R peak, phone time.
    public let lastBeatMs: Double
    /// The interval that ended at it.
    public let rrMs: Double

    public static let staleAfterMs = 3_000.0
    /// How fast a pulse fades: to 1/e after this long.
    public static let decayMs = 150.0

    public init(lastBeatMs: Double, rrMs: Double) {
        self.lastBeatMs = lastBeatMs
        self.rrMs = rrMs
    }

    /// 1 on a beat, falling toward 0 until the next; 0 before the last beat and once stale.
    public func intensity(atMs: Double) -> Double {
        let since = atMs - lastBeatMs
        guard since >= 0, since < Self.staleAfterMs, rrMs > 0 else { return 0 }
        return exp(-since.truncatingRemainder(dividingBy: rrMs) / Self.decayMs)
    }
}
