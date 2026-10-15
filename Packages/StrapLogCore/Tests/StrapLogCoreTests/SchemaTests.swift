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
        #expect(rows.map { $0["value"] as String } == ["straplog", "1"])
    }

    @Test("docs/SCHEMA.md contains the v1 migration verbatim")
    func docsMatch() throws {
        let docs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/SCHEMA.md")
        let text = try String(contentsOf: docs, encoding: .utf8)
        let block = try #require(text.components(separatedBy: "```sql\n").dropFirst().first?
            .components(separatedBy: "```").first)
        #expect(block.trimmingCharacters(in: .whitespacesAndNewlines)
                == Schema.v1.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
