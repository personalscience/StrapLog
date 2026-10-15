import Foundation

/// A running breathing pacer: equal inhale and exhale at a fixed rate, from `startedAtMs`.
public struct BreathingPacer: Sendable, Equatable {
    /// Allowed rates in breaths per minute, adjustable in `rateStep` steps.
    public static let rates: ClosedRange<Double> = 4.5...7
    public static let rateStep = 0.5
    public static let defaultRate = 6.0

    public let breathsPerMinute: Double
    public let startedAtMs: Int64

    public init(breathsPerMinute: Double, startedAtMs: Int64) {
        precondition(Self.rates.contains(breathsPerMinute), "pacer rate outside \(Self.rates)")
        self.breathsPerMinute = breathsPerMinute
        self.startedAtMs = startedAtMs
    }

    /// One full breath (in + out).
    public var periodMs: Double { 60_000 / breathsPerMinute }

    /// `event.note` for `pacer_start`, e.g. `6.0/min`.
    public var note: String { String(format: "%.1f/min", breathsPerMinute) }

    /// Where in the breath the pacer is at `atMs`. Times before the start read as the start.
    public func phase(atMs: Int64) -> BreathPhase {
        let elapsed = Double(max(0, atMs - startedAtMs))
        let half = periodMs / 2
        let intoBreath = elapsed.truncatingRemainder(dividingBy: periodMs)
        let inhaling = intoBreath < half
        let progress = (inhaling ? intoBreath : intoBreath - half) / half
        return BreathPhase(inhaling: inhaling, progress: progress,
                           secondsLeft: (1 - progress) * half / 1000)
    }
}
