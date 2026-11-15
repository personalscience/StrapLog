import StrapLogCore

/// Notices when the band's 0x2A37 notifications stop while the link still looks connected.
/// The band notifies about once a second, even off the arm (it sends HR 0), so silence always
/// means a lost subscription: BaroLog's live HR froze at one value until relaunch (straplog-ydg.6).
///
/// A periodic `check` answers `.resubscribe` after `stallMs` of silence, then `.reconnect` if HR
/// is still silent `stallMs` after that. The source calls `reset` on every connect and disconnect.
public struct HeartRateWatchdog: Sendable {
    public enum Action: Sendable, Equatable { case none, resubscribe, reconnect }

    private var dog: StreamWatchdog
    private var armed = false
    private var resubscribed = false

    public init(stallMs: Int64 = StreamWatchdog.defaultStallMs) {
        dog = StreamWatchdog(retryMs: stallMs, stallMs: stallMs)
    }

    /// Connected, or HR notifications requested: silence counts from here.
    public mutating func started(atMs: Int64) {
        _ = dog.attempted(atMs: atMs)
        armed = true
    }

    /// One 0x2A37 notification.
    public mutating func received(atMs: Int64) {
        dog.received(atMs: atMs)
        resubscribed = false
    }

    public mutating func check(atMs: Int64) -> Action {
        guard armed, dog.restartDue(atMs: atMs) else { return .none }
        if resubscribed { return .reconnect }
        resubscribed = true
        _ = dog.attempted(atMs: atMs)
        return .resubscribe
    }

    public mutating func reset() {
        dog.reset()
        armed = false
        resubscribed = false
    }
}
