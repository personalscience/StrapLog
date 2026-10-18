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
    /// How long the face shows a heart rate: the refresh interval plus slack for a late
    /// reload. Past it the face shows none rather than a number it cannot vouch for.
    public static let heartRateShownMs: Int64 = 20 * 60_000
    /// How long the face shows a recording without news: the phone's check-in interval plus
    /// slack. Past it the face says when it last heard rather than run a timer it cannot vouch for.
    public static let recordingShownMs: Int64 = FacePushPolicy.checkInMs + 30 * 60_000

    public init(status: LiveStatus?, receivedAtMs: Int64) {
        self.status = status
        self.receivedAtMs = receivedAtMs
    }

    public var receivedAt: Date { Date(timeIntervalSince1970: Double(receivedAtMs) / 1000) }

    /// What the face shows at `date`: the heart rate and then the recording expire unless a
    /// newer snapshot replaces this one.
    public func face(at date: Date) -> ComplicationFace {
        guard let status else { return .idle }
        guard date < expiry(Self.recordingShownMs) else { return .noWord(since: receivedAt) }
        return .recording(status, heartRate: date < expiry(Self.heartRateShownMs) ? status.heartRate : nil)
    }

    /// The moments after `date` at which `face(at:)` changes; the widget schedules an entry at each.
    public func faceChanges(after date: Date) -> [Date] {
        guard status != nil else { return [] }
        return [expiry(Self.heartRateShownMs), expiry(Self.recordingShownMs)].filter { $0 > date }
    }

    private func expiry(_ shownMs: Int64) -> Date {
        receivedAt.addingTimeInterval(Double(shownMs) / 1000)
    }

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
