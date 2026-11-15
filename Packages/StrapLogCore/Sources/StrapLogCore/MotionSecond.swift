import Foundation
import GRDB

/// One `motion` row: accelerometer activity over one wall-clock second.
/// Values are whole mg, which SQLite stores as small integers even in `REAL` columns.
public struct MotionSecond: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "motion"

    public var recordingId: Int64
    /// Start of the second, Unix epoch ms UTC (a multiple of 1000).
    public var secondMs: Int64
    /// RMS of |a| around its own mean over the second (its standard deviation): 0 when still,
    /// larger with movement. Measured around the second's mean rather than an assumed 1 g, so a
    /// sensor whose scale is off (the armband reads 0.94–0.98 g at rest) still reads 0 when
    /// still. Rows written before 2026-11-15 used |a| − 1 g (`docs/SCHEMA.md`).
    public var rmsMg: Double
    /// Mean acceleration per axis: the gravity vector, so posture.
    public var gxMg: Double
    public var gyMg: Double
    public var gzMg: Double
    /// Samples in the second (25 at 25 Hz).
    public var n: Int

    public init(recordingId: Int64, secondMs: Int64, rmsMg: Double, gxMg: Double, gyMg: Double, gzMg: Double, n: Int) {
        self.recordingId = recordingId
        self.secondMs = secondMs
        self.rmsMg = rmsMg
        self.gxMg = gxMg
        self.gyMg = gyMg
        self.gzMg = gzMg
        self.n = n
    }

    /// The same second with `other`'s samples pooled in, as if reduced together (up to rounding,
    /// and ignoring any difference between the halves' mean |a|, which is not stored).
    /// Needed when a second is split, e.g. by a relaunch that restarts the reducer mid-second.
    public func merged(with other: MotionSecond) -> MotionSecond {
        let total = Double(n + other.n)
        func mean(_ a: Double, _ b: Double) -> Double { ((a * Double(n) + b * Double(other.n)) / total).rounded() }
        let rms = ((rmsMg * rmsMg * Double(n) + other.rmsMg * other.rmsMg * Double(other.n)) / total).squareRoot()
        return MotionSecond(recordingId: recordingId, secondMs: secondMs, rmsMg: rms.rounded(),
                            gxMg: mean(gxMg, other.gxMg), gyMg: mean(gyMg, other.gyMg), gzMg: mean(gzMg, other.gzMg),
                            n: n + other.n)
    }

    /// Inserts each second, merging into a row already stored for the same second.
    static func save(_ seconds: [MotionSecond], db: Database) throws {
        for second in seconds {
            let stored = try MotionSecond.fetchOne(db, key: ["recording_id": second.recordingId,
                                                             "second_ms": second.secondMs])
            try (stored?.merged(with: second) ?? second).save(db)
        }
    }

    enum CodingKeys: String, CodingKey {
        case n
        case recordingId = "recording_id", secondMs = "second_ms", rmsMg = "rms_mg"
        case gxMg = "gx_mg", gyMg = "gy_mg", gzMg = "gz_mg"
    }
}
