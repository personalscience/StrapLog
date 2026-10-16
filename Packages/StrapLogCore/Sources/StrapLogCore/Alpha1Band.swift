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
        self = Self.allCases.first { alpha1 >= $0.lowerBound } ?? .veryHard
    }

    /// Lowest α1 in the band; the band runs up to the next one's `lowerBound` (or 1.0 → ∞).
    public var lowerBound: Double {
        switch self {
        case .rest: 1.0
        case .easy: 0.75
        case .moderate: 0.5
        case .veryHard: 0
        }
    }

    /// Highest α1 in the band (exclusive), or `.infinity` for `.rest`.
    public var upperBound: Double {
        switch self {
        case .rest: .infinity
        case .easy: 1.0
        case .moderate: 0.75
        case .veryHard: 0.5
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
