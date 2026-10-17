/// `event.kind` values. Stored as text; this enum is the only place the vocabulary lives.
public enum EventKind: String, Codable, Sendable, CaseIterable {
    case start, stop, marker, connect, disconnect, relaunch
    case bleOff = "ble_off"
    case bleOn = "ble_on"
    case snapshot
    case pacerStart = "pacer_start"
    case pacerStop = "pacer_stop"
    case lowBattery = "low_battery"
    case foreground, background
    /// Overnight only: a confirmed `Posture` change, noted `upright` or `lying`.
    case posture
}
