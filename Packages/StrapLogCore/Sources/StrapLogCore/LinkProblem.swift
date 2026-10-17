/// Why the recording has stopped getting beats, as the Watch and the phone's alert see it.
public enum LinkProblem: Sendable, Equatable {
    /// No status for `LiveStatus.staleAfterMs`: the phone app or the Watch link is gone.
    case stale
    case disconnected
    case contactLost
    /// Linked and in contact, but no beats (`LiveStatus.beatGap`).
    case beatGap

    /// One line for an alert.
    public var message: String {
        switch self {
        case .stale: "No update from the iPhone for over a minute."
        case .disconnected: "The H10 disconnected."
        case .contactLost: "The H10 lost skin contact."
        case .beatGap: "The H10 has sent no beats for 10 seconds."
        }
    }
}
