import AppIntents

/// Siri phrases and the Shortcuts app's StrapLog tiles; also offered to the Action button.
struct StrapLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartRecordingIntent(),
                    phrases: ["Start \(\.$activity) recording in \(.applicationName)",
                              "Start recording \(\.$activity) in \(.applicationName)",
                              "Start \(.applicationName)"],
                    shortTitle: "Start Recording", systemImageName: "record.circle")
        AppShortcut(intent: StopRecordingIntent(),
                    phrases: ["Stop \(.applicationName)", "Stop recording in \(.applicationName)"],
                    shortTitle: "Stop Recording", systemImageName: "stop.circle")
        AppShortcut(intent: AddMarkerIntent(),
                    phrases: ["Add a marker in \(.applicationName)", "Mark \(.applicationName)"],
                    shortTitle: "Add Marker", systemImageName: "flag")
    }
}
