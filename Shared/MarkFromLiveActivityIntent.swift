import AppIntents
import StrapLogCore

/// A marker button on the Live Activity; runs in the app's process (`StopFromLiveActivityIntent`).
struct MarkFromLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Marker"
    static let isDiscoverable = false

    @Parameter(title: "Marker")
    var label: String

    @Dependency private var launcher: Launcher

    init() {}

    init(label: String) {
        self.label = label
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await launcher.whenLaunched { [label] in await $0.markIfRecording(label) }
        return .result()
    }
}
