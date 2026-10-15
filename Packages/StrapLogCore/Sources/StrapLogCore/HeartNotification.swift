import GRDB

/// One `notification` row: a single HR measurement as received (≈1 Hz).
public struct HeartNotification: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "notification"

    public var id: Int64?
    public var recordingId: Int64
    public var receivedAtMs: Int64
    public var hrBpm: Int
    public var contact: Bool?
    public var nRR: Int

    public init(recordingId: Int64, receivedAtMs: Int64, hrBpm: Int, contact: Bool?, nRR: Int) {
        self.recordingId = recordingId
        self.receivedAtMs = receivedAtMs
        self.hrBpm = hrBpm
        self.contact = contact
        self.nRR = nRR
    }

    enum CodingKeys: String, CodingKey {
        case id, contact
        case recordingId = "recording_id", receivedAtMs = "received_at_ms"
        case hrBpm = "hr_bpm", nRR = "n_rr"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
