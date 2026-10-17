import Foundation
import GRDB

/// `index.json` in an export folder: one entry per snapshot file there, newest first, so an
/// agent finds recordings by reading one file instead of opening every snapshot. Rewritten
/// after each export and delete. Recordings whose file is elsewhere (the other export folder)
/// are left out; an iCloud file evicted from the device (`.<name>.icloud`) still counts.
public struct ExportIndex: Codable, Sendable, Equatable {
    public static let fileName = "index.json"
    public static let format = "straplog-index"
    public static let version = 1

    public var format = ExportIndex.format
    public var version = ExportIndex.version
    public var generatedAtMs: Int64
    public var appVersion: String
    public var recordings: [ExportIndexEntry]

    enum CodingKeys: String, CodingKey {
        case format, version, recordings
        case generatedAtMs = "generated_at_ms", appVersion = "app_version"
    }

    /// Entries for the recordings among `files` (names in the folder), newest first.
    public static func build(_ db: Database, files: Set<String>, appVersion: String,
                             generatedAtMs: Int64) throws -> ExportIndex {
        let recordings = try Recording.order(sql: "started_at_ms DESC, id DESC").fetchAll(db)
            .filter { files.contains(Snapshot.fileName(for: $0)) }
        let beats = try Dictionary(uniqueKeysWithValues: Row.fetchAll(db, sql: """
            SELECT recording_id, COUNT(*) AS n FROM beat GROUP BY recording_id
            """).map { ($0["recording_id"] as Int64, $0["n"] as Int) })
        let labels = try Dictionary(grouping: Row.fetchAll(db, sql: """
            SELECT recording_id, label FROM event WHERE kind = 'marker' AND label IS NOT NULL ORDER BY at_ms, id
            """), by: { $0["recording_id"] as Int64 }).mapValues { $0.map { $0["label"] as String } }
        let entries = try recordings.map { rec in
            let id = rec.id ?? 0
            return ExportIndexEntry(rec, beats: beats[id] ?? 0,
                                    coverage: try Coverage.of(recording: id, db: db),
                                    labels: labels[id] ?? [])
        }
        return ExportIndex(generatedAtMs: generatedAtMs, appVersion: appVersion, recordings: entries)
    }

    /// Rewrites `index.json` in `directory` from the database; does nothing if the folder is missing.
    public static func refresh(_ database: StrapLogDatabase, in directory: URL, appVersion: String,
                               nowMs: Int64) throws {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        let files = Set(names.map(Self.downloadedName))
        let index = try database.writer.read { db in
            try build(db, files: files, appVersion: appVersion, generatedAtMs: nowMs)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try CoordinatedFile.write(try encoder.encode(index), to: directory.appendingPathComponent(fileName))
    }

    /// `.<name>.icloud` (an evicted iCloud placeholder) → `<name>`; other names unchanged.
    static func downloadedName(_ name: String) -> String {
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return name }
        return String(name.dropFirst().dropLast(".icloud".count))
    }
}
