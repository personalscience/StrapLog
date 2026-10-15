import GRDB

/// One `event` row: start/stop, markers, link changes, relaunches, snapshots.
public struct RecordingEvent: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "event"

    public var id: Int64?
    public var recordingId: Int64
    public var atMs: Int64
    public var kind: EventKind
    public var note: String?

    public init(recordingId: Int64, atMs: Int64, kind: EventKind, note: String? = nil) {
        self.recordingId = recordingId
        self.atMs = atMs
        self.kind = kind
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, note
        case recordingId = "recording_id", atMs = "at_ms"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
