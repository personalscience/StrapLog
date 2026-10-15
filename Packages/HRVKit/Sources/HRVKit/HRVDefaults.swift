/// Constants mirrored from `~/dev/skills/h10-session/.../analyze_h10.py`.
/// Change them there first; the fixtures record the values they were made with.
public enum HRVDefaults {
    /// Physiological gate, inclusive (Python drops `< 300` and `> 2000`).
    public static let rrGateMs: ClosedRange<Double> = 300...2000
    /// `PCT_THRESH_DEFAULT`: relative deviation from the local median that marks an artifact.
    public static let pctThresh = 0.25
    /// `clean_rr` runs the median filter at most this many times.
    public static let cleanIterations = 3
    /// Centered rolling-median width and its `min_periods`.
    public static let medianWindow = 5
    public static let medianMinPeriods = 3

    /// `WINDOW_SEC_DEFAULT`, `STRIDE_SEC_DEFAULT`.
    public static let windowSeconds = 120.0
    public static let strideSeconds = 60.0
    /// `MIN_BEATS_PER_WIN`, applied to both raw and cleaned beats.
    public static let minBeatsPerWindow = 60

    /// `DFA_SCALE_MIN...DFA_SCALE_MAX`.
    public static let dfaScales: ClosedRange<Int> = 4...16
}
