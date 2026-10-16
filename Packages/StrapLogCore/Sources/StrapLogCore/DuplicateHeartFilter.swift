/// Drops a heart-rate event that is a second observer's copy of the previous one. The Polar SDK
/// can start a second HR observer task on the same GATT client when it re-runs service discovery
/// (online streaming needs encryption, so the H10 answers `uuidNotAllowed` and the SDK
/// rediscovers); every notification then arrives twice, once per task, in the same millisecond.
///
/// Payload alone cannot tell a copy from a real beat: after a BLE stall genuine notifications
/// arrive back to back and occasionally match exactly (same bpm, same RR). Those come from the
/// same observer, so a repeat is dropped only when a *different* observer delivers it.
/// Other payloads always pass.
public struct DuplicateHeartFilter: Sendable {
    public static let defaultWindowMs: Int64 = 100

    private let windowMs: Int64
    private var last: (event: SensorEvent, observer: Int?)?

    public init(windowMs: Int64 = defaultWindowMs) {
        self.windowMs = windowMs
    }

    /// True when `event` should be kept. `observer` identifies the delivering SDK task
    /// (nil when unknown, which never counts as a different observer).
    public mutating func admit(_ event: SensorEvent, observer: Int?) -> Bool {
        guard case .heartRate = event.payload else { return true }
        if let last, last.event.payload == event.payload, event.atMs - last.event.atMs <= windowMs,
           let observer, let previous = last.observer, observer != previous {
            return false
        }
        last = (event, observer)
        return true
    }
}
