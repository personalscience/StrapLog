import GRDB

/// One `event` row: start/stop, markers, link changes, relaunches, snapshots.
public struct RecordingEvent: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "event"

    public var id: Int64?
    public var recordingId: Int64
    public var atMs: Int64
    public var kind: EventKind
    public var note: String?
    /// A marker's word from its preset's vocabulary (`ActivityPreset.markers`); nil otherwise.
    public var label: String?

    public init(recordingId: Int64, atMs: Int64, kind: EventKind, label: String? = nil, note: String? = nil) {
        self.recordingId = recordingId
        self.atMs = atMs
        self.kind = kind
        self.label = label
        self.note = note
    }

    /// Label and note as one line, e.g. `awake`, `felt dizzy`, `awake · bathroom`.
    public var markerText: String {
        [label, note].compactMap { $0 }.joined(separator: " · ")
    }

    /// Distinct free-text marker notes across all recordings, most recently used first.
    public static func recentNotes(_ db: Database, limit: Int) throws -> [String] {
        try String.fetchAll(db, sql: """
            SELECT note FROM event WHERE kind = 'marker' AND note IS NOT NULL
            GROUP BY note ORDER BY MAX(id) DESC LIMIT ?
            """, arguments: [limit])
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, note, label
        case recordingId = "recording_id", atMs = "at_ms"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
