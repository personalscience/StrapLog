/// Windowed HRV over a beat series, matching `rolling_features` in analyze_h10.py:
/// each window is cleaned independently and skipped (nil) when either the raw or
/// the cleaned beat count is below `minBeats`.
public struct WindowAnalyzer: Sendable {
    public var window: SlidingWindow
    public var cleaner: RRCleaner
    public var minBeats: Int

    public init(window: SlidingWindow = SlidingWindow(),
                cleaner: RRCleaner = RRCleaner(),
                minBeats: Int = HRVDefaults.minBeatsPerWindow) {
        self.window = window
        self.cleaner = cleaner
        self.minBeats = minBeats
    }

    /// Features for every window with enough beats. `beats` are RR (ms) stamped
    /// with seconds since the recording's first beat, sorted by time.
    public func features(_ beats: [TimedSample<Double>]) -> [WindowFeatures] {
        window.windows(over: beats).compactMap { features(of: $0.values, center: $0.center) }
    }

    /// Features for one window's raw RR values, or nil if it has too few beats.
    public func features(of raw: [Double], center: Double) -> WindowFeatures? {
        guard raw.count >= minBeats else { return nil }
        let clean = cleaner.clean(raw).kept
        guard clean.count >= minBeats, let hr = TimeDomain.meanHR(clean) else { return nil }
        return WindowFeatures(
            tCenter: center,
            nRaw: raw.count,
            nBeats: clean.count,
            hrBpm: hr,
            rmssd: TimeDomain.rmssd(clean),
            lnRMSSD: TimeDomain.lnRMSSD(clean),
            sdnn: TimeDomain.sdnn(clean),
            alpha1: DFA.alpha1(clean)
        )
    }
}
