/// Why an overnight recording stopped itself; stored as the `stop` event's note.
public enum AutoStop: String, Sendable, Equatable {
    /// The plan's wake time arrived.
    case wakeTime = "wake_time"
    /// Upright for `uprightStopMs` after having lain down.
    case upright
}
