import GRDB

/// One `beat` row: a single RR interval, positioned within its notification.
public struct Beat: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "beat"

    public var id: Int64?
    public var recordingId: Int64
    public var notificationId: Int64
    public var idx: Int
    public var rr1024: Int
    public var rrMs: Double
    public var tEndMsEst: Int64

    public init(recordingId: Int64, notificationId: Int64, idx: Int, rr1024: Int, tEndMsEst: Int64) {
        self.recordingId = recordingId
        self.notificationId = notificationId
        self.idx = idx
        self.rr1024 = rr1024
        self.rrMs = BeatTiming.ms(fromRR1024: rr1024)
        self.tEndMsEst = tEndMsEst
    }

    enum CodingKeys: String, CodingKey {
        case id, idx
        case recordingId = "recording_id", notificationId = "notification_id"
        case rr1024 = "rr_1024", rrMs = "rr_ms", tEndMsEst = "t_end_ms_est"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
