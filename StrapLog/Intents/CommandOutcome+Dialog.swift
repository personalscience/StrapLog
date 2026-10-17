import AppIntents
import StrapLogCore

extension CommandOutcome {
    /// What Shortcuts shows or Siri says; `done` words the success. Throws on `failed`.
    func dialog(done: (Recording) -> String) throws -> IntentDialog {
        switch self {
        case .done(let rec): IntentDialog(stringLiteral: done(rec))
        case .alreadyRecording(let rec): IntentDialog(stringLiteral: "Already recording \(rec.name).")
        case .notRecording: "StrapLog is not recording."
        case .failed(let message): throw CommandFailed(message: message)
        }
    }
}
