import HRVKit

/// What `RSATracker` makes of heart rate against the pacer's breath, after each beat.
public struct RSAReading: Sendable, Equatable {
    /// End time of the latest beat, Unix epoch ms.
    public let atMs: Int64
    /// Cleaned beat-to-beat HR (bpm) at each kept beat's mid-interval, the last
    /// `RSADefaults.traceSeconds`, oldest first.
    public let trace: [TrendPoint]
    /// The last `RSATracker.keptBreaths` whole pacer breaths, oldest first. Their times are
    /// seconds from the pacer's `startedAtMs`.
    public let breaths: [BreathSwing]
    /// The cosinor over the last `RSADefaults.windowBreaths` whole breaths: fitted swing, sync
    /// and peak position. Nil until that many breaths have closed, or when the window has holes.
    public let fit: CosinorFit?
    /// True until `RSATracker.warmUpBreaths` whole breaths have closed.
    public let warmingUp: Bool

    /// Smallest bar scale for the per-breath swings (bpm), so a calm run does not fill the bars.
    public static let minBarTopBpm = 10.0

    /// The top of the per-breath bars: the largest swing shown, at least `minBarTopBpm`, whole bpm.
    public var barTopBpm: Double {
        max(Self.minBarTopBpm, (breaths.compactMap(\.swing).max() ?? 0).rounded(.up))
    }

    /// Where the fitted peak sits against the target; nil without a fit.
    public var judgement: RSAJudgement? { fit.map(RSAJudgement.init) }

    public init(atMs: Int64, trace: [TrendPoint], breaths: [BreathSwing], fit: CosinorFit?, warmingUp: Bool) {
        self.atMs = atMs
        self.trace = trace
        self.breaths = breaths
        self.fit = fit
        self.warmingUp = warmingUp
    }
}
