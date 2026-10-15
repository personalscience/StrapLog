/// A silence between consecutive HR notifications longer than `Coverage`'s threshold.
public struct CoverageGap: Sendable, Equatable {
    /// Receive time of the notification before the gap.
    public var startMs: Int64
    /// Receive time of the notification after the gap.
    public var endMs: Int64
    /// Event kinds logged inside the gap, in order.
    public var events: [EventKind]

    public var durationMs: Int64 { endMs - startMs }

    /// The gap is explained: the link went down (`disconnect`, `ble_off`, or the app died
    /// and came back as `relaunch`) and later came back up (`connect`, `ble_on`) inside it.
    public var isBracketed: Bool {
        guard let down = events.firstIndex(where: { [.disconnect, .bleOff, .relaunch].contains($0) }) else {
            return false
        }
        return events[down...].contains { [.connect, .bleOn].contains($0) }
    }

    public init(startMs: Int64, endMs: Int64, events: [EventKind]) {
        self.startMs = startMs
        self.endMs = endMs
        self.events = events
    }
}
