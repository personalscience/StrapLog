import GRDB

/// A row of the Home screen's recordings list.
public struct RecordingSummary: Sendable, Equatable, Identifiable, FetchableRecord, Decodable {
    public var id: Int64
    public var name: String
    public var activity: String
    public var startedAtMs: Int64
    public var endedAtMs: Int64?
    public var tzOffsetS: Int
    public var beatCount: Int

    public init(id: Int64, name: String, activity: String = ActivityPreset.other.id, startedAtMs: Int64, endedAtMs: Int64?, tzOffsetS: Int, beatCount: Int) {
        self.id = id
        self.name = name
        self.activity = activity
        self.startedAtMs = startedAtMs
        self.endedAtMs = endedAtMs
        self.tzOffsetS = tzOffsetS
        self.beatCount = beatCount
    }

    enum CodingKeys: String, CodingKey {
        case id, name, activity
        case startedAtMs = "started_at_ms", endedAtMs = "ended_at_ms", tzOffsetS = "tz_offset_s"
        case beatCount = "beat_count"
    }

    /// Newest first.
    public static func all(_ db: Database) throws -> [RecordingSummary] {
        try RecordingSummary.fetchAll(db, sql: """
            SELECT r.id, r.name, r.activity, r.started_at_ms, r.ended_at_ms, r.tz_offset_s,
                   (SELECT COUNT(*) FROM beat b WHERE b.recording_id = r.id) AS beat_count
            FROM recording r
            ORDER BY r.started_at_ms DESC, r.id DESC
            """)
    }
}
