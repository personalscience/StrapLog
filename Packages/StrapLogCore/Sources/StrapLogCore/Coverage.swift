import GRDB

/// How much of a recording has HR data: the span from first to last notification, minus
/// every silence longer than `gapThresholdMs`. The H10 notifies about once a second, so the
/// default 3 s threshold ignores ordinary jitter and a single dropped notification.
public struct Coverage: Sendable, Equatable {
    public static let defaultGapThresholdMs: Int64 = 3000

    /// First to last notification receive time; 0 with fewer than two notifications.
    public var spanMs: Int64
    public var gaps: [CoverageGap]

    public var gapMs: Int64 { gaps.reduce(0) { $0 + $1.durationMs } }

    /// Covered share of the span, 0…1; 0 for an empty span.
    public var fraction: Double { spanMs > 0 ? Double(spanMs - gapMs) / Double(spanMs) : 0 }

    /// Gaps not explained by a down/up pair of link events.
    public var unbracketedGaps: [CoverageGap] { gaps.filter { !$0.isBracketed } }

    public init(spanMs: Int64, gaps: [CoverageGap]) {
        self.spanMs = spanMs
        self.gaps = gaps
    }

    public static func of(recording id: Int64, gapThresholdMs: Int64 = defaultGapThresholdMs,
                          db: Database) throws -> Coverage {
        let times = try Int64.fetchAll(db, sql: """
            SELECT received_at_ms FROM notification WHERE recording_id = ? ORDER BY received_at_ms
            """, arguments: [id])
        guard let first = times.first, let last = times.last else { return Coverage(spanMs: 0, gaps: []) }
        let events = try RecordingEvent.fetchAll(db, sql: """
            SELECT * FROM event WHERE recording_id = ? ORDER BY at_ms, id
            """, arguments: [id])

        var gaps: [CoverageGap] = []
        for (a, b) in zip(times, times.dropFirst()) where b - a > gapThresholdMs {
            let inside = events.filter { $0.atMs >= a && $0.atMs <= b }.map(\.kind)
            gaps.append(CoverageGap(startMs: a, endMs: b, events: inside))
        }
        return Coverage(spanMs: last - first, gaps: gaps)
    }
}
