import AppIntents
import StrapLogCore

/// Stops and exports the open recording, as the Stop button does.
struct StopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description = IntentDescription("Stops the StrapLog recording and exports it to iCloud Drive.")

    @Dependency private var launcher: Launcher

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = try await launcher.whenLaunched { await $0.stopIfRecording() }
        return .result(dialog: try outcome.dialog { "Stopped \($0.name) and exported it." })
    }
}
