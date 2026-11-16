import Foundation
import GRDB

/// Your resonance rate (straplog-9fr.11): the best rate of the latest resonance-finder run, or
/// the one picked with 'Use X/min', with when its recording started. Kept in `UserDefaults`
/// (`PacerSettings.resonanceKey`), not the database: it is a setting, not data. With none kept,
/// the latest finished finder recording supplies it (`latestFinder`), so runs from before it was
/// kept, or restored from snapshots, still count.
public struct ResonanceResult: Codable, Sendable, Equatable {
    /// Breaths a minute.
    public let rate: Double
    /// When the recording that found it started (Unix ms UTC).
    public let foundAtMs: Int64
    /// That recording's UTC offset, so the date reads as it did where it was found.
    public let tzOffsetS: Int

    public init(rate: Double, foundAtMs: Int64, tzOffsetS: Int) {
        self.rate = rate
        self.foundAtMs = foundAtMs
        self.tzOffsetS = tzOffsetS
    }

    /// The best rate of `detail`'s ranking; nil when it ranks nothing.
    public init?(_ detail: RecordingDetail) {
        guard let ranking = detail.resonance else { return nil }
        self.init(rate: ranking.best.rate, foundAtMs: detail.recording.startedAtMs, tzOffsetS: detail.recording.tzOffsetS)
    }

    /// The answer of the latest finished resonance-finder run that ranks its rates, found by its
    /// opening marker (`training`, noted `resonance v…`); nil when there is none.
    public static func latestFinder(db: Database) throws -> ResonanceResult? {
        let ids = try Int64.fetchAll(db, sql: """
            SELECT r.id FROM recording r JOIN event e ON e.recording_id = r.id
            WHERE e.kind = 'marker' AND e.label = ? AND e.note LIKE ? AND r.ended_at_ms IS NOT NULL
            ORDER BY r.started_at_ms DESC
            """, arguments: [TrainingScript.introLabel, TrainingScript.resonance.name + " v%"])
        for id in ids {
            if let result = try RecordingDetail.load(id, db: db).flatMap(ResonanceResult.init) { return result }
        }
        return nil
    }

    /// Nil when missing or unreadable.
    public static func load(from defaults: UserDefaults) -> ResonanceResult? {
        defaults.data(forKey: PacerSettings.resonanceKey).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: PacerSettings.resonanceKey)
    }
}
