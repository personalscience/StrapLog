/// Intensity band for a DFA α1 value, cut at 1.0, 0.75 (≈ VT1) and 0.50 (≈ VT2).
/// The names match the colour-band table in `MetricsGuide.md`.
public enum Alpha1Band: Sendable, Equatable, CaseIterable {
    /// α1 ≥ 1.0
    case rest
    /// 0.75 ≤ α1 < 1.0: below the aerobic threshold.
    case easy
    /// 0.50 ≤ α1 < 0.75: between thresholds.
    case moderate
    /// α1 < 0.50: above the anaerobic threshold.
    case veryHard

    public init(alpha1: Double) {
        switch alpha1 {
        case 1.0...: self = .rest
        case 0.75..<1.0: self = .easy
        case 0.5..<0.75: self = .moderate
        default: self = .veryHard
        }
    }

    public var label: String {
        switch self {
        case .rest: "rest / very easy"
        case .easy: "easy"
        case .moderate: "moderate"
        case .veryHard: "very hard"
        }
    }
}
