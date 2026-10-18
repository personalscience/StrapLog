/// Picks the Watch's `HeartRateSource`: the phone first, the strap's broadcasts only while the
/// phone has no fresh HR, and nothing while the app is off screen (scanning costs battery).
/// Fed by events (a status arriving, reachability changing, the app coming forward) plus the
/// Watch's periodic stale check; it never polls.
public struct HeartRateSourcePolicy: Sendable {
    /// A phone status older than this no longer counts as fresh HR: a backstop for a phone that
    /// is reachable but silent. Above `LiveStatusThrottle.defaultMinIntervalMs`, so routine
    /// pushes keep the phone current.
    public static let phoneQuietAfterMs: Int64 = 20_000

    public private(set) var source: HeartRateSource = .idle
    /// When the strap took over, so only a status that arrives after it hands back to the phone.
    private var strapSinceMs: Int64?

    public init() {}

    /// The source for now. `status` is the phone's latest (nil when it is not recording) and
    /// `receivedAtMs` when it arrived.
    public mutating func update(isForeground: Bool, isReachable: Bool, status: LiveStatus?, receivedAtMs: Int64?,
                                nowMs: Int64) -> HeartRateSource {
        guard isForeground else {
            strapSinceMs = nil
            source = .idle
            return source
        }
        let fresh: Bool = if let status, let receivedAtMs {
            status.linked && status.heartRate != nil && nowMs - receivedAtMs <= Self.phoneQuietAfterMs
        } else {
            false
        }
        if let strapSinceMs {
            // Back only on a fresh status heard since: reachability alone would flap at range's edge.
            guard fresh, let receivedAtMs, receivedAtMs > strapSinceMs else { return source }
            self.strapSinceMs = nil
            source = .phone
        } else if fresh && isReachable {
            source = .phone
        } else {
            strapSinceMs = nowMs
            source = .strap
        }
        return source
    }
}
