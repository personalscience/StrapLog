import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("Schema")
struct SchemaTests {
    @Test("migration is idempotent on the same connection")
    func idempotentInMemory() throws {
        let queue = try DatabaseQueue()
        _ = try StrapLogDatabase(queue)
        _ = try StrapLogDatabase(queue)
        let tables = try queue.read { try String.fetchAll($0, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'grdb_%' ORDER BY name") }
        #expect(tables == ["beat", "event", "meta", "motion", "notification", "recording"])
        let meta = try queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM meta") }
        #expect(meta == 2)
    }

    @Test("reopening a file database keeps data and does not re-migrate")
    func idempotentOnDisk() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("live.sqlite")

        let first = try TestRig(database: .live(at: url))
        try await first.session.start(name: "x")
        let reopened = try StrapLogDatabase.live(at: url)
        let n = try await reopened.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM recording") }
        #expect(n == 1)
        let mode = try await reopened.writer.read { try String.fetchOne($0, sql: "PRAGMA journal_mode") }
        #expect(mode == "wal")
    }

    @Test("meta identifies the format for loaders")
    func meta() throws {
        let db = try StrapLogDatabase.inMemory()
        let rows = try db.writer.read { try Row.fetchAll($0, sql: "SELECT key, value FROM meta ORDER BY key") }
        #expect(rows.map { $0["key"] as String } == ["format", "schema_version"])
        #expect(rows.map { $0["value"] as String } == ["straplog", "3"])
    }

    @Test("motion is WITHOUT ROWID, so a night of it stays small")
    func motionWithoutRowid() throws {
        let db = try StrapLogDatabase.inMemory()
        let sql = try db.writer.read { try String.fetchOne($0, sql: "SELECT sql FROM sqlite_master WHERE name = 'motion'") }
        #expect(sql?.hasSuffix("WITHOUT ROWID") == true)
    }

    @Test("v3 upgrades a v2 file: old recordings become `other`, old markers keep their note")
    func v3FromV2() throws {
        let queue = try DatabaseQueue()
        var v2 = DatabaseMigrator()
        for (name, sql) in Schema.migrations.prefix(2) {
            v2.registerMigration(name) { db in try db.execute(sql: sql) }
        }
        try v2.migrate(queue)
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO recording(id, name, started_at_ms, tz_offset_s) VALUES (1, 'old', 0, 0);
                INSERT INTO event(recording_id, at_ms, kind, note) VALUES (1, 0, 'marker', 'a');
                """)
        }
        _ = try StrapLogDatabase(queue)
        let rec = try queue.read { try Recording.fetchOne($0, key: 1) }
        #expect(rec?.activity == "other")
        #expect(rec?.context == nil)
        let marker = try queue.read { try RecordingEvent.fetchOne($0) }
        #expect(marker?.note == "a")
        #expect(marker?.label == nil)
        #expect(marker?.markerText == "a")
    }

    @Test("docs/SCHEMA.md contains every migration verbatim, in order")
    func docsMatch() throws {
        let docs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/SCHEMA.md")
        let text = try String(contentsOf: docs, encoding: .utf8)
        let blocks = text.components(separatedBy: "```sql\n").dropFirst()
            .compactMap { $0.components(separatedBy: "```").first?.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(blocks == Schema.migrations.map { $0.1.trimmingCharacters(in: .whitespacesAndNewlines) })
    }
}
