import AppIntents
import StrapLogCore

/// The Live Activity's Stop button. A `LiveActivityIntent` runs in the app's process, where
/// the `Launcher` dependency lives, though the widget extension compiles it too.
struct StopFromLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let isDiscoverable = false

    @Dependency private var launcher: Launcher

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await launcher.whenLaunched { await $0.stopIfRecording() }
        return .result()
    }
}
