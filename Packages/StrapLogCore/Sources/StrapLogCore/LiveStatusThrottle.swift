/// Decides which `LiveStatus` values reach the display. ActivityKit rate-limits updates, and
/// HR arrives every second, so routine changes go out at most every `minIntervalMs`; a start,
/// a stop, a link or contact change, or a new marker goes out at once.
public struct LiveStatusThrottle: Sendable {
    public let minIntervalMs: Int64
    private var shown: LiveStatus?
    private var shownAtMs: Int64?

    /// Default `minIntervalMs`: within the plan's 5–10 s; α1 and RMSSD only change every 20 s.
    public static let defaultMinIntervalMs: Int64 = 10_000

    public init(minIntervalMs: Int64 = LiveStatusThrottle.defaultMinIntervalMs) {
        self.minIntervalMs = minIntervalMs
    }

    /// Whether to show `status` now; records it as shown when true.
    public mutating func admit(_ status: LiveStatus?, atMs: Int64) -> Bool {
        // The first call always goes out, so a launch with no recording ends a leftover activity.
        guard status != shown || shownAtMs == nil else { return false }
        let due = shownAtMs.map { atMs - $0 >= minIntervalMs } ?? true
        guard due || isUrgent(status) else { return false }
        shown = status
        shownAtMs = atMs
        return true
    }

    private func isUrgent(_ status: LiveStatus?) -> Bool {
        guard let status, let shown else { return true }
        return status.startedAtMs != shown.startedAtMs || status.linked != shown.linked
            || status.contact != shown.contact || status.markerCount != shown.markerCount
            || status.markers != shown.markers
    }
}
