import Foundation

/// A running breathing pacer: a fixed rate and inhale:exhale ratio, from `startedAtMs`.
public struct BreathingPacer: Sendable, Equatable {
    /// Allowed rates in breaths per minute, adjustable in `rateStep` steps. Resonance rates sit
    /// in 4.5–7; 7.5–10 are controls, e.g. breathing at 10/min to move breath away from the
    /// ~0.1 Hz Mayer band.
    public static let rates: ClosedRange<Double> = 4.5...10
    public static let rateStep = 0.5
    public static let defaultRate = 6.0

    public let breathsPerMinute: Double
    public let ratio: BreathRatio
    public let startedAtMs: Int64

    public init(breathsPerMinute: Double, ratio: BreathRatio = .default, startedAtMs: Int64) {
        precondition(Self.rates.contains(breathsPerMinute), "pacer rate outside \(Self.rates)")
        self.breathsPerMinute = breathsPerMinute
        self.ratio = ratio
        self.startedAtMs = startedAtMs
    }

    /// One full breath (in + out).
    public var periodMs: Double { 60_000 / breathsPerMinute }

    public var inhaleMs: Double { periodMs * ratio.inhaleFraction }
    public var exhaleMs: Double { periodMs - inhaleMs }

    /// The full length of the inhale, or of the exhale.
    public func lengthMs(inhaling: Bool) -> Double { inhaling ? inhaleMs : exhaleMs }

    /// What the file records about this pacer.
    public var stamp: PacerStamp {
        PacerStamp(breathsPerMinute: breathsPerMinute, inhaleS: inhaleMs / 1000, exhaleS: exhaleMs / 1000,
                   t0Ms: startedAtMs)
    }

    /// The rate alone, e.g. `6.0/min`.
    public var rateText: String { stamp.rateText }

    /// `event.note` for `pacer_start`, e.g. `6.0/min in5.0 out5.0 t0=1762070400000`.
    public var note: String { stamp.note }

    /// The first turn after `afterMs`, to the whole ms: the half of the breath it begins, which
    /// is the opposite of the half `afterMs` is in. Before the start, that is the first inhale.
    public func nextTransition(afterMs: Int64) -> (atMs: Int64, inhaling: Bool) {
        var breath = max(0, (Double(afterMs - startedAtMs) / periodMs).rounded(.down) - 1)
        while true {
            let inhale = startedAtMs + Int64((breath * periodMs).rounded())
            if inhale > afterMs { return (inhale, true) }
            let exhale = startedAtMs + Int64((breath * periodMs + inhaleMs).rounded())
            if exhale > afterMs { return (exhale, false) }
            breath += 1
        }
    }

    /// Every turn after `fromMs` up to and including `toMs`, oldest first: where the ECG strip
    /// draws its inhale and exhale lines.
    public func transitions(afterMs fromMs: Int64, throughMs toMs: Int64) -> [(atMs: Int64, inhaling: Bool)] {
        var out: [(atMs: Int64, inhaling: Bool)] = []
        var next = nextTransition(afterMs: fromMs)
        while next.atMs <= toMs {
            out.append(next)
            next = nextTransition(afterMs: next.atMs)
        }
        return out
    }

    /// Where in the breath the pacer is at `atMs`. Times before the start read as the start.
    public func phase(atMs: Int64) -> BreathPhase {
        let elapsed = Double(max(0, atMs - startedAtMs))
        let intoBreath = elapsed.truncatingRemainder(dividingBy: periodMs)
        let inhaling = intoBreath < inhaleMs
        let length = inhaling ? inhaleMs : exhaleMs
        let progress = (inhaling ? intoBreath : intoBreath - inhaleMs) / length
        return BreathPhase(inhaling: inhaling, progress: progress,
                           secondsLeft: (1 - progress) * length / 1000)
    }
}
