import AppIntents
import StrapLogCore

/// Marks the open recording now. Text matching one of the activity's marker buttons is
/// stored as that label; anything else as a note.
struct AddMarkerIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Marker"
    static let description = IntentDescription("Adds a marker to the StrapLog recording, e.g. awake or a free-text note.")

    @Parameter(title: "Marker", requestValueDialog: "What happened?")
    var text: String

    @Dependency private var launcher: Launcher

    static var parameterSummary: some ParameterSummary {
        Summary("Add marker \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await launcher.whenLaunched { [text] in await $0.markIfRecording(text) }
        return .result(dialog: try outcome.dialog { _ in "Marked \(text)." })
    }
}
