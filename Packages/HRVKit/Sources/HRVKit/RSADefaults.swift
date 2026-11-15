/// Constants for respiratory sinus arrhythmia (heart rate following the breath).
/// The first three are mirrored in `tools/gen_rsa_fixture.py` (the fixture records them);
/// the two fit gates are Swift-only until straplog-py gets `rsa()` (straplog-9fr.6).
public enum RSADefaults {
    /// Whole pacer breaths in one cosinor window (40 s at 6/min).
    public static let windowBreaths = 4
    /// A breath with fewer HR samples has no swing (`MIN_BEATS_PER_BREATH`).
    public static let minBeatsPerBreath = 4
    /// A gap between HR samples longer than this is a hole (`MAX_HOLE_MS`).
    public static let maxHoleSeconds = 3.0
    /// A cosinor window needs at least this many samples per breath.
    public static let minSamplesPerFitBreath = 3
    /// A cosinor window whose holes add up to more than this share of it has no fit.
    public static let maxHoleFraction = 0.25
    /// RR context the live tracker cleans, and the span of the drawn trace.
    public static let contextSeconds = 120.0
    public static let traceSeconds = 60.0

    /// Where in the breath HR should peak (fraction from inhale start). Rik, 2026-11-15:
    /// his followed 6/min steps peak at 0.64–0.73, so 0.6 rather than the textbook 0.5.
    public static let peakTargetFraction = 0.6
    /// Distance from the target, in breaths, that still reads green and amber.
    public static let peakGreenBand = 0.1
    public static let peakAmberBand = 0.2
}
