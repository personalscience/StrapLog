import AppIntents
import StrapLogCore

/// The Watch's one-press marker, for the Ultra's Action button (Settings → Action Button →
/// Shortcut → Next Marker) or Siri. The phone picks the label (`RemoteCommand.markNext`).
struct MarkNextIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Marker"
    static let description = IntentDescription("Adds the next marker to the StrapLog recording on the iPhone.")
    static let openAppWhenRun = false

    @Dependency private var phone: PhoneLink

    @MainActor
    func perform() async throws -> some IntentResult {
        await phone.send(.markNext)
        return .result()
    }
}
