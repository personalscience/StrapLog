/// HRV metrics for one window, the Swift counterpart of a `rolling_features` row.
public struct WindowFeatures: Sendable, Equatable {
    public let tCenter: Double
    public let nRaw: Int
    /// Beats left after cleaning (`n_beats` in Python).
    public let nBeats: Int
    public let hrBpm: Double
    public let rmssd: Double?
    public let lnRMSSD: Double?
    public let sdnn: Double?
    public let alpha1: Double?

    public var artifactRate: Double { Double(nRaw - nBeats) / Double(nRaw) }
}
