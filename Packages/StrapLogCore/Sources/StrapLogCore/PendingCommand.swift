/// A start or stop the Watch has sent and not yet seen land. Settled when the phone's status
/// shows the new state; until then the Watch shows what it is waiting for instead of the
/// buttons, so a second tap cannot queue a second start.
public struct PendingCommand: Sendable, Equatable {
    public let command: RemoteCommand
    /// Sent with `transferUserInfo`: the phone was out of reach and runs it when it is back.
    public var queued = false
    /// The phone's answer when the command failed.
    public var failure: String?

    public init(_ command: RemoteCommand) {
        self.command = command
    }

    /// Whether `status` (nil while idle) is the state this command was sent to reach.
    public func isSettled(by status: LiveStatus?) -> Bool {
        switch command {
        case .start: status != nil
        case .stop: status == nil
        case .mark, .markNext: true
        }
    }

    /// `Starting Sleep…`, `Stopping…`, or the wait for an unreachable phone.
    public var waitingText: String {
        if queued { return "Waiting for iPhone…" }
        return switch command {
        case .start(let activity, _): "Starting \(ActivityPreset.named(activity).title)…"
        case .stop: "Stopping…"
        case .mark, .markNext: "Marking…"
        }
    }
}
