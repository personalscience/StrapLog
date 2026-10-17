import Foundation

/// A command's `CommandOutcome.failed` message, shown by Shortcuts or spoken by Siri.
struct CommandFailed: Error, CustomLocalizedStringResourceConvertible {
    let message: String

    var localizedStringResource: LocalizedStringResource { "\(message)" }
}
