import Foundation
import GRDB

/// The migrated database. Live recordings use a WAL `DatabasePool`; tests use memory.
public struct StrapLogDatabase: Sendable {
    public let writer: any DatabaseWriter

    /// Wraps `writer` and brings it to the latest schema (a no-op if already there).
    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Schema.migrator.migrate(writer)
    }

    public static func inMemory() throws -> StrapLogDatabase {
        try StrapLogDatabase(DatabaseQueue())
    }

    /// `Application Support/StrapLog/live.sqlite` in the app; any path in tests. WAL mode.
    public static func live(at url: URL) throws -> StrapLogDatabase {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        return try StrapLogDatabase(DatabasePool(path: url.path))
    }
}
