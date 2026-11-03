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

    /// Distinct free-text marker notes across all recordings, most recently used first; case
    /// variants count as one note.
    public static func recentNotes(_ db: Database, limit: Int) throws -> [RecentNote] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT e.note, r.activity FROM event e JOIN recording r ON r.id = e.recording_id
            WHERE e.kind = 'marker' AND e.note IS NOT NULL
            GROUP BY e.note, r.activity ORDER BY MAX(e.id) DESC
            """)
        return RecentNote.merged(rows.map { (text: $0["note"], activity: $0["activity"]) }, limit: limit)
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, note, label
        case recordingId = "recording_id", atMs = "at_ms"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
