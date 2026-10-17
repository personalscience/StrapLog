/// Why an overnight recording stopped itself; stored as the `stop` event's note.
public enum AutoStop: String, Sendable, Equatable {
    /// The wake time arrived and the resting reading after it is done, or was skipped because
    /// the body was already upright.
    case wakeTime = "wake_time"
    /// Upright for `uprightStopMs` after having lain down.
    case upright
}
