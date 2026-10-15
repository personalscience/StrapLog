import Foundation

/// A moment in a paced breath, as `BreathingPacer.phase(atMs:)` reports it.
public struct BreathPhase: Sendable, Equatable {
    public let inhaling: Bool
    /// 0 at the start of this inhale (or exhale), approaching 1 at its end.
    public let progress: Double
    /// Seconds until the switch to the other half of the breath.
    public let secondsLeft: Double

    /// Lung fill for the animation: 0 empty, 1 full, eased so the turn at each end is gentle.
    public var volume: Double {
        let eased = (1 - cos(.pi * progress)) / 2
        return inhaling ? eased : 1 - eased
    }

    public var instruction: String { inhaling ? "Breathe in" : "Breathe out" }
}
