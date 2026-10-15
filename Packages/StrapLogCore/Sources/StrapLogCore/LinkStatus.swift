/// What the UI shows about the strap connection.
public enum LinkStatus: Sendable, Equatable {
    /// No connection seen yet this launch.
    case searching
    case connected(deviceId: String)
    case disconnected
    case bluetoothOff
}
