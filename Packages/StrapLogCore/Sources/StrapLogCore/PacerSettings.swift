import Foundation

/// The pacer's remembered rate, in `UserDefaults`, so it survives relaunches and is the same
/// on Home and Recording.
public enum PacerSettings {
    public static let rateKey = "pacerBreathsPerMinute"

    public static let ratioKey = "pacerBreathRatio"
    /// Whether the pacer plays its tones (`PacerCueSink`); off unless the user turns it on.
    public static let soundKey = "pacerSound"
    /// Whether the pacer screen streams the live ECG and pulses on its beats; off by default.
    public static let ecgKey = "pacerECG"
    /// Whether the pacer screen shows the breath measured by the strap (`BreathTracker`); off by default.
    public static let breathKey = "pacerBreath"

    /// The saved inhale:exhale ratio; missing or unknown values read as the default.
    public static func ratio(_ stored: String?) -> BreathRatio {
        stored.flatMap(BreathRatio.init(rawValue:)) ?? .default
    }

    /// `stored` as a rate `BreathingPacer` accepts: snapped to `rateStep` within `rates`.
    public static func rate(_ stored: Double) -> Double {
        guard stored.isFinite else { return BreathingPacer.defaultRate }
        let step = BreathingPacer.rateStep
        let snapped = (stored / step).rounded() * step
        return min(max(snapped, BreathingPacer.rates.lowerBound), BreathingPacer.rates.upperBound)
    }
}
