/// One step of a `TrainingScript`. Its marker `label` is logged when its line `say` starts.
///
/// A paced step (`pacerRate` set) starts the pacer `leadInMs` after the line, so the first chime
/// is not under the voice, runs `durationMs` from the pacer's `t0`, and ends at an in-breath
/// turn, i.e. at the end of an out-breath. An unpaced step (silence, or a hold) runs `durationMs`
/// from its start.
public struct TrainingStep: Sendable, Equatable {
    public let label: String
    public let say: String
    /// Breaths a minute, within `BreathingPacer.rates`; nil for no chimes.
    public let pacerRate: Double?
    public let leadInMs: Int64
    public let durationMs: Int64
    public let lines: [TrainingLine]

    /// Default `leadInMs` of a paced step: the line has finished before the first chime.
    public static let defaultLeadInMs: Int64 = 6_000

    /// A step with no chimes.
    public static func quiet(_ label: String, say: String, seconds: Int64, lines: [TrainingLine] = []) -> TrainingStep {
        TrainingStep(label: label, say: say, pacerRate: nil, leadInMs: 0, durationMs: seconds * 1000, lines: lines)
    }

    /// A step that follows the chimes at `rate` for `seconds`.
    public static func paced(_ label: String, say: String, rate: Double, seconds: Int64,
                             leadInMs: Int64 = defaultLeadInMs, lines: [TrainingLine] = []) -> TrainingStep {
        TrainingStep(label: label, say: say, pacerRate: rate, leadInMs: leadInMs, durationMs: seconds * 1000, lines: lines)
    }

    /// How long one breath lasts, for a paced step.
    public var periodMs: Double? { pacerRate.map { 60_000 / $0 } }

    /// Breaths in a paced step (fractional if the length is not a whole number of them).
    public var breaths: Double? { periodMs.map { Double(durationMs) / $0 } }

    /// From the step's start to its planned end, lead-in included.
    public var totalMs: Int64 { leadInMs + durationMs }

    /// When a line said one breath before the end lands: 1 s into the last in-breath, clear of its chime.
    public static func lastBreathMs(seconds: Int64, rate: Double) -> Int64 {
        seconds * 1000 - Int64((60_000 / rate).rounded()) + 1000
    }
}
