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
    /// Whether the pacer screen shows heart rate following the breath (`RSATracker`); off by default.
    public static let rsaKey = "pacerRSA"
    /// Your resonance rate and when it was found (`ResonanceResult`, JSON).
    public static let resonanceKey = "resonanceResult"

    /// The saved inhale:exhale ratio; missing or unknown values read as the default.
    public static func ratio(_ stored: String?) -> BreathRatio {
        stored.flatMap(BreathRatio.init(rawValue:)) ?? .default
    }

    /// The saved rate, snapped; the default when none is saved.
    public static func rate(in defaults: UserDefaults) -> Double {
        (defaults.object(forKey: rateKey) as? Double).map(rate) ?? BreathingPacer.defaultRate
    }

    /// `stored` as a rate `BreathingPacer` accepts: snapped to `rateStep` within `rates`.
    public static func rate(_ stored: Double) -> Double {
        guard stored.isFinite else { return BreathingPacer.defaultRate }
        let step = BreathingPacer.rateStep
        let snapped = (stored / step).rounded() * step
        return min(max(snapped, BreathingPacer.rates.lowerBound), BreathingPacer.rates.upperBound)
    }
}
