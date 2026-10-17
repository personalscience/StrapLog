import AppIntents
import StrapLogCore

/// Starts a recording without opening the app, e.g. from a "Sleep Focus on" automation.
/// An overnight activity uses the wake time set on the Start screen. A recording already
/// open keeps running.
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static let description = IntentDescription("Starts a StrapLog recording of an activity. Sleep stops at the wake time set in the app.")

    @Parameter(title: "Activity")
    var activity: ActivityEntity

    @Parameter(title: "Name", description: "Blank for the activity and date, e.g. sleep 2026-10-16.")
    var name: String?

    @Dependency private var launcher: Launcher

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$activity) recording") { \.$name }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let preset = ActivityPreset.named(activity.id)
        let plan = StartPreferences.plan(from: .standard)
        let outcome = await launcher.whenLaunched { await $0.startUnlessRecording(preset, name: name ?? "", plan: plan) }
        return .result(dialog: try outcome.dialog { "Recording \($0.name)." })
    }
}
