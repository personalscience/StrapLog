import Foundation

/// How a breath divides between inhale and exhale.
///
/// The raw values are stored in `UserDefaults` (`PacerSettings.ratioKey`): never rename them.
public enum BreathRatio: String, CaseIterable, Sendable {
    case equal, fourSix, oneTwo

    public static let `default` = BreathRatio.equal

    /// Share of one breath spent inhaling.
    public var inhaleFraction: Double {
        switch self {
        case .equal: 0.5
        case .fourSix: 0.4
        case .oneTwo: 1.0 / 3.0
        }
    }

    /// Inhale:exhale as shown to the user.
    public var title: String {
        switch self {
        case .equal: "1:1"
        case .fourSix: "4:6"
        case .oneTwo: "1:2"
        }
    }
}
