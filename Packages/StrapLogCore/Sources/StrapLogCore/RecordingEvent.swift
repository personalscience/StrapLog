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

    enum CodingKeys: String, CodingKey {
        case id, kind, note, label
        case recordingId = "recording_id", atMs = "at_ms"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
