import GRDB

/// One `recording` row: a named session from Start to Stop, surviving relaunches.
public struct Recording: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "recording"

    public var id: Int64?
    public var name: String
    public var startedAtMs: Int64
    public var endedAtMs: Int64?
    public var tzOffsetS: Int
    public var deviceId: String?
    public var firmware: String?
    public var batteryStart: Int?
    public var batteryEnd: Int?
    public var notes: String?
    /// `ActivityPreset.id`; `other` for recordings made before activities existed.
    public var activity: String
    /// Free JSON object describing the session (pack kg, route, ...); nil when there is none.
    public var context: String?

    public init(name: String, activity: String = ActivityPreset.other.id, startedAtMs: Int64, tzOffsetS: Int) {
        self.name = name
        self.activity = activity
        self.startedAtMs = startedAtMs
        self.tzOffsetS = tzOffsetS
    }

    enum CodingKeys: String, CodingKey {
        case id, name, firmware, notes, activity, context
        case startedAtMs = "started_at_ms", endedAtMs = "ended_at_ms", tzOffsetS = "tz_offset_s"
        case deviceId = "device_id", batteryStart = "battery_start", batteryEnd = "battery_end"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    /// The most recent recording without `ended_at_ms`: what a relaunch should resume.
    public static func open(_ db: Database) throws -> Recording? {
        try Recording
            .filter(sql: "ended_at_ms IS NULL")
            .order(sql: "started_at_ms DESC, id DESC")
            .fetchOne(db)
    }
}
