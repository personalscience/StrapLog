/// What a command from outside the app (Shortcuts, Siri, the Action button) did, so it can
/// answer in words instead of failing silently into `RecorderModel.errorMessage`.
public enum CommandOutcome: Sendable, Equatable {
    /// Done to this recording: started, stopped, or marked.
    case done(Recording)
    /// Start while one is open: left running untouched.
    case alreadyRecording(Recording)
    /// Stop or marker while idle.
    case notRecording
    case failed(String)
}
