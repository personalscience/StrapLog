import Foundation

/// The pacer's remembered rate, in `UserDefaults`, so it survives relaunches and is the same
/// on Home and Recording.
public enum PacerSettings {
    public static let rateKey = "pacerBreathsPerMinute"

    /// `stored` as a rate `BreathingPacer` accepts: snapped to `rateStep` within `rates`.
    public static func rate(_ stored: Double) -> Double {
        guard stored.isFinite else { return BreathingPacer.defaultRate }
        let step = BreathingPacer.rateStep
        let snapped = (stored / step).rounded() * step
        return min(max(snapped, BreathingPacer.rates.lowerBound), BreathingPacer.rates.upperBound)
    }
}
