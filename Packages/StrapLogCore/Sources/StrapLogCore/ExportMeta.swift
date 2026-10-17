import Foundation

/// The `meta` rows a snapshot carries beyond `format` and `schema_version`, so a reader
/// knows what the file is without this app's source: the preset it was recorded with, the
/// event vocabulary, the time basis and which build wrote it. Export-only; the live DB has none.
public enum ExportMeta {
    public static let schemaDoc = "https://github.com/personalscience/StrapLog/blob/main/docs/SCHEMA.md"
    public static let timeBasis = "*_ms are Unix epoch ms UTC; local time = UTC + recording.tz_offset_s"

    public static func rows(for recording: Recording, appVersion: String, exportedAtMs: Int64) throws -> [String: String] {
        [
            "app_version": appVersion,
            "exported_at_ms": String(exportedAtMs),
            "preset": try json(ActivityPreset.named(recording.activity)),
            "event_kinds": try json(EventKind.allCases.map(\.rawValue)),
            "time_basis": timeBasis,
            "schema_doc": schemaDoc,
        ]
    }

    private static func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
