/// The phone's answer to a Watch start or stop: its status once the command has run, so the
/// Watch need not wait for (or miss) the application context, and why it failed, if it did.
public struct CommandReply: Sendable, Codable, Equatable {
    /// Nil while idle.
    public let status: LiveStatus?
    public let failure: String?

    public init(status: LiveStatus?, failure: String? = nil) {
        self.status = status
        self.failure = failure
    }

    /// What `outcome` leaves to say: only a failure; the status shows the rest.
    public init(_ outcome: CommandOutcome, status: LiveStatus?) {
        if case .failed(let message) = outcome {
            self.init(status: status, failure: message)
        } else {
            self.init(status: status)
        }
    }
}
