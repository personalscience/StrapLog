/// A training session as data: what is said, what is paced, and for how long (ArmLog's
/// Training mode, run by `TrainingRunner`). Every step follows the chimes, holds, or moves;
/// tests on the data enforce the rules the analysis relies on (`TrainingScriptTests`).
public struct TrainingScript: Sendable, Equatable {
    public let name: String
    public let version: Int
    /// The name of the recording a run starts.
    public let recordingName: String
    /// Whether the run's recording keeps every accelerometer sample (`acc`), for replaying the
    /// breath tracker; only the armband scripts need it.
    public let rawMotion: Bool
    /// Whether a run's answer is your resonance rate: said at the end and kept
    /// (`TrainingRunner`). Only the resonance finder; other scripts that pace several rates
    /// (the calibration) rank them on the detail screen but do not claim to have found it.
    public let findsResonance: Bool
    public let steps: [TrainingStep]

    public init(name: String, version: Int, recordingName: String, rawMotion: Bool, findsResonance: Bool = false,
                steps: [TrainingStep]) {
        self.name = name
        self.version = version
        self.recordingName = recordingName
        self.rawMotion = rawMotion
        self.findsResonance = findsResonance
        self.steps = steps
    }

    /// The first marker's note, e.g. `calibration v1`.
    public var stamp: String { "\(name) v\(version)" }

    /// The planned length, lead-ins included.
    public var totalMs: Int64 { steps.reduce(0) { $0 + $1.totalMs } }

    /// The label of the marker that opens every run.
    public static let introLabel = "training"
    /// The label of the marker that closes a finished run.
    public static let endLabel = "end"
    /// The label of the marker logged when a run stops early.
    public static let abortedLabel = "aborted"

    private static func intro(_ text: String) -> TrainingStep {
        .quiet(introLabel, say: text, seconds: 10)
    }

    private static let tenMore = TrainingLine(afterMs: 20_000, text: "Ten more.")

    /// The breath-tracker calibration protocol, ~19 min: each paced step is a cold-started
    /// tracker's transient plus at least one full 60 s window, and at least 8 breaths.
    public static let calibration = TrainingScript(name: "calibration", version: 1, recordingName: "breath calibration",
                                                rawMotion: true, steps: [
        intro("Training session. Rest both arms on the armrests and keep still. Breathe naturally; I'll tell you each step."),
        .quiet("settle", say: "Breathe naturally.", seconds: 90),
        .paced("follow_6", say: "Follow the chimes, six breaths a minute.", rate: 6, seconds: 180),
        .paced("follow_10", say: "Faster now: ten a minute.", rate: 10, seconds: 120),
        .paced("follow_4.5", say: "Slow now: four and a half a minute.", rate: 4.5, seconds: 120),
        .paced("follow_8", say: "Eight a minute.", rate: 8, seconds: 120, lines: [
            TrainingLine(afterMs: TrainingStep.lastBreathMs(seconds: 120, rate: 8), text: "After this breath out, hold."),
        ]),
        .quiet("hold_1", say: "Hold.", seconds: 30, lines: [tenMore]),
        .paced("recover_1", say: "Breathe.", rate: 6, seconds: 60, leadInMs: 0, lines: [
            TrainingLine(afterMs: TrainingStep.lastBreathMs(seconds: 60, rate: 6), text: "After this breath out, hold again."),
        ]),
        .quiet("hold_2", say: "Hold.", seconds: 30, lines: [tenMore]),
        .paced("recover_2", say: "Breathe.", rate: 6, seconds: 60, leadInMs: 0),
        .quiet("move", say: "Move the arm with the band about freely.", seconds: 20, lines: [
            TrainingLine(afterMs: 15_000, text: "Settle, arms back on the armrests."),
        ]),
        .paced("after_move", say: "Follow the chimes again, six a minute.", rate: 6, seconds: 120),
        // A longer lead-in: the arm moves to the thigh and settles before the chimes.
        .paced("armpos", say: "Rest the arm with the band on your thigh, then follow the chimes.", rate: 6,
               seconds: 120, leadInMs: 10_000),
    ])

    /// A 2-minute device check: hear the voice, try one hold after the out-breath.
    public static let rehearsal = TrainingScript(name: "rehearsal", version: 1, recordingName: "breath calibration",
                                              rawMotion: true, steps: [
        intro("Rehearsal. Keep still and breathe naturally."),
        .quiet("settle", say: "Breathe naturally.", seconds: 20),
        .paced("follow_6", say: "Follow the chimes, six breaths a minute.", rate: 6, seconds: 40, lines: [
            TrainingLine(afterMs: TrainingStep.lastBreathMs(seconds: 40, rate: 6), text: "After this breath out, hold."),
        ]),
        .quiet("hold_1", say: "Hold.", seconds: 30, lines: [tenMore]),
        .paced("recover_1", say: "Breathe.", rate: 6, seconds: 30, leadInMs: 0),
    ])

    /// The resonance finder (straplog-9fr.7), ~13 min on the strap: 2 min at each rate from 7
    /// down to 4.5 /min in 0.5 steps, each a whole number of breaths. Afterwards the recording's
    /// pacer runs are ranked by median swing (`ResonanceRanking`) on its detail screen.
    public static let resonance = TrainingScript(name: "resonance", version: 1, recordingName: "resonance finder",
                                                 rawMotion: false, findsResonance: true, steps: [
        intro("Resonance finder. Sit still and follow the chimes. The rate slows every two minutes."),
        .paced("follow_7", say: "Seven breaths a minute.", rate: 7, seconds: 120),
        .paced("follow_6.5", say: "Six and a half.", rate: 6.5, seconds: 120),
        .paced("follow_6", say: "Six.", rate: 6, seconds: 120),
        .paced("follow_5.5", say: "Five and a half.", rate: 5.5, seconds: 120),
        .paced("follow_5", say: "Five.", rate: 5, seconds: 120),
        .paced("follow_4.5", say: "Four and a half, the slowest.", rate: 4.5, seconds: 120),
    ])

    /// Every script, for the rules in `TrainingScriptTests`; each app offers its own list.
    public static let all = [calibration, rehearsal, resonance]
}
