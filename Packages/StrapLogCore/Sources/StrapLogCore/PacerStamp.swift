import Foundation

/// What a `pacer_start` event's note says was paced, e.g. `6.0/min in5.0 out5.0 t0=1762070400000`.
/// The one Swift definition of the grammar in `docs/SCHEMA.md`. The pacer is deterministic, so
/// these parameters reconstruct every cue; the rate comes first so readers of the pre-1.2 note
/// (`6.0/min` alone: equal halves, origin unknown) keep working on its first token.
public struct PacerStamp: Sendable, Equatable {
    public let breathsPerMinute: Double
    public let inhaleS: Double
    public let exhaleS: Double
    /// When the pacer started (epoch ms UTC), which precedes the event's `at_ms` if a recording
    /// began while it was running. Nil in a pre-1.2 note; the origin is then the event's `at_ms`.
    public let t0Ms: Int64?

    public init(breathsPerMinute: Double, inhaleS: Double, exhaleS: Double, t0Ms: Int64?) {
        self.breathsPerMinute = breathsPerMinute
        self.inhaleS = inhaleS
        self.exhaleS = exhaleS
        self.t0Ms = t0Ms
    }

    /// Nil if `note` does not follow the grammar. A missing `in` or `out` is half the breath.
    public init?(note: String) {
        let grammar = #/(\d+(?:\.\d+)?)\/min(?: in(\d+(?:\.\d+)?))?(?: out(\d+(?:\.\d+)?))?(?: t0=(\d+))?/#
        guard let match = note.wholeMatch(of: grammar),
              let rate = Double(match.1), rate > 0 else { return nil }
        let half = 30 / rate
        breathsPerMinute = rate
        inhaleS = match.2.flatMap { Double($0) } ?? half
        exhaleS = match.3.flatMap { Double($0) } ?? half
        t0Ms = match.4.flatMap { Int64($0) }
    }

    /// The in-breath's share of the breath.
    public var inhaleFraction: Double { inhaleS / (inhaleS + exhaleS) }

    /// The rate alone, e.g. `6.0/min`.
    public var rateText: String { String(format: "%.1f/min", breathsPerMinute) }

    /// The note this stamp is written as; in and out are to 0.1 s.
    public var note: String {
        let times = String(format: "%@ in%.1f out%.1f", rateText, inhaleS, exhaleS)
        return t0Ms.map { "\(times) t0=\($0)" } ?? times
    }
}
