import Foundation

/// What the Watch face's complication shows: the phone's latest `LiveStatus` (nil while idle)
/// and when it arrived. WidgetKit budgets reloads, so the face is a state indicator, not a
/// live meter: `replaces(_:)` decides which statuses are worth a reload.
public struct ComplicationSnapshot: Sendable, Codable, Equatable {
    public let status: LiveStatus?
    public let receivedAtMs: Int64

    /// How old the shown heart rate may grow before a status with nothing else new reloads
    /// the face; WidgetKit allows a background app about four reloads an hour.
    public static let heartRateRefreshMs: Int64 = 15 * 60_000

    public init(status: LiveStatus?, receivedAtMs: Int64) {
        self.status = status
        self.receivedAtMs = receivedAtMs
    }

    public var receivedAt: Date { Date(timeIntervalSince1970: Double(receivedAtMs) / 1000) }

    /// The link problem when the status arrived. Staleness is left out: without a reload the
    /// face cannot tell a quiet phone from a Watch app that was not woken.
    public var problem: LinkProblem? { status?.problem(isStale: false) }

    /// Whether this snapshot should reload a face showing `shown`: a recording started or
    /// stopped, its link problem changed, or the shown heart rate is `heartRateRefreshMs` old.
    public func replaces(_ shown: ComplicationSnapshot?) -> Bool {
        guard let shown else { return true }
        if status?.startedAtMs != shown.status?.startedAtMs || problem != shown.problem { return true }
        return status != nil && receivedAtMs - shown.receivedAtMs >= Self.heartRateRefreshMs
    }
}
