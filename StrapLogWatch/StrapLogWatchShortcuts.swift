import AppIntents

/// Lists `MarkNextIntent` in the Watch's Shortcuts, where the Action button can pick it.
struct StrapLogWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MarkNextIntent(), phrases: ["Mark next in \(.applicationName)"],
                    shortTitle: "Next Marker", systemImageName: "flag.fill")
    }
}
