/// A command from outside the app's screens: Shortcuts and Siri, the Live Activity buttons, the
/// Watch. All of them go through `Launcher.run(_:)`, so each answers with the same
/// `CommandOutcome`. `Codable` so the Watch can send it over WatchConnectivity.
public enum RemoteCommand: Sendable, Codable, Hashable {
    /// Start `activity` (an `ActivityPreset.id`) unless a recording is open; a blank `name`
    /// means the activity and date.
    case start(activity: String, name: String = "")
    case stop
    /// One of the activity's marker labels, or a free-text note.
    case mark(String)
    /// The activity's next marker (`LiveStatus.nextMarker`), decided by the phone: the Watch's
    /// Action button has no screen to pick one on.
    case markNext
}
