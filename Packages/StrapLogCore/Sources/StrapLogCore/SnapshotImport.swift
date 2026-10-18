import Foundation
import GRDB

/// Brings snapshot files back into the live database, e.g. after deleting and reinstalling the
/// app wiped it while the exports survived in iCloud Drive.
///
/// A file imports only the recording whose `Snapshot.fileName` is the file's own name, so an
/// old multi-recording export never resurrects recordings deleted since. A recording already in
/// the database (same `started_at_ms` and `device_id`) is skipped. Row ids are remapped: the
/// recording keeps its id when free, child ids are shifted past the live maximum. A recording
/// left open in its snapshot is imported closed at its last activity (`stop` noted `imported`).
///
/// Files whose name matches a live recording are never opened, so a run with nothing to import
/// costs one directory listing per folder. A bad file is skipped; the others still import.
public enum SnapshotImport {
    /// `stop` note on a recording that was still open in its snapshot.
    public static let importedNote = "imported"

    /// Imports every new snapshot in `folders` (the newest copy of a name wins). Files evicted
    /// from iCloud (`.<name>.icloud`) are passed to `requestDownload` as `<name>` and import on
    /// a later run.
    /// Returns the ids of the imported recordings.
    @discardableResult
    public static func run(_ database: StrapLogDatabase, folders: [URL],
                           requestDownload: (URL) -> Void = { _ in }) throws -> [Int64] {
        let known = try database.writer.read { db in
            Set(try Recording.fetchAll(db).map(Snapshot.fileName(for:)))
        }
        let (files, placeholders) = candidates(in: folders, known: known)
        placeholders.forEach(requestDownload)
        return files.compactMap { try? importFile($0, into: database) }
    }

    /// Unknown snapshot files (the newest copy per name) and unknown evicted files, by real name.
    static func candidates(in folders: [URL], known: Set<String>) -> (files: [URL], placeholders: [URL]) {
        let fm = FileManager.default
        var newest: [String: (url: URL, modified: Date)] = [:]
        var placeholders: [URL] = []
        for folder in folders {
            guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names {
                let snapshot = ExportIndex.downloadedName(name)
                guard snapshot.hasSuffix(".sqlite"), !known.contains(snapshot) else { continue }
                let url = folder.appendingPathComponent(snapshot)
                guard snapshot == name else { placeholders.append(url); continue }
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if let kept = newest[name], kept.modified >= modified { continue }
                newest[name] = (url, modified)
            }
        }
        let files = newest.values.map(\.url).sorted { $0.lastPathComponent < $1.lastPathComponent }
        return (files, placeholders)
    }

    /// Imports the recording that `url` is named for; nil if the file holds none or it is
    /// already in the database. Throws on a file that is not a readable StrapLog snapshot.
    static func importFile(_ url: URL, into database: StrapLogDatabase) throws -> Int64? {
        let fm = FileManager.default
        let scratch = fm.temporaryDirectory.appendingPathComponent("StrapLogImport-\(UUID().uuidString)")
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scratch) }
        // Opened only as a private copy: SQLite must never write a journal into iCloud Drive.
        let copy = scratch.appendingPathComponent("snapshot.sqlite")
        try CoordinatedFile.copy(url, to: copy)
        guard let rec = try prepare(copy, named: url.lastPathComponent), let oldId = rec.id else { return nil }
        return try insert(rec, oldId: oldId, from: copy, into: database)
    }

    /// Migrates the private copy to the current schema and returns its named recording.
    private static func prepare(_ copy: URL, named name: String) throws -> Recording? {
        let queue = try DatabaseQueue(path: copy.path)
        defer { try? queue.close() }
        let format = try queue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'format'")
        }
        guard format == "straplog" else { throw SnapshotImportError.notASnapshot }
        guard try !queue.read({ try Schema.migrator.hasBeenSuperseded($0) }) else { throw SnapshotImportError.newerSchema }
        try Schema.migrator.migrate(queue)
        return try queue.read { db in
            try Recording.fetchAll(db).first { Snapshot.fileName(for: $0) == name }
        }
    }

    private static func insert(_ rec: Recording, oldId: Int64, from copy: URL,
                               into database: StrapLogDatabase) throws -> Int64? {
        try database.writer.writeWithoutTransaction { db in
            try db.execute(sql: "ATTACH DATABASE ? AS snap", arguments: [copy.path])
            defer { try? db.execute(sql: "DETACH DATABASE snap") }
            var imported: Int64?
            try db.inTransaction {
                imported = try copyRows(rec, oldId: oldId, db: db)
                return .commit
            }
            return imported
        }
    }

    /// Copies one recording and its rows from `snap` into `main`, in the caller's transaction.
    private static func copyRows(_ rec: Recording, oldId: Int64, db: Database) throws -> Int64? {
        let duplicate = try Bool.fetchOne(db, sql: """
            SELECT EXISTS(SELECT 1 FROM main.recording WHERE started_at_ms = ? AND device_id IS ?)
            """, arguments: [rec.startedAtMs, rec.deviceId]) ?? false
        guard !duplicate else { return nil }
        let taken = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM main.recording WHERE id = ?)",
                                      arguments: [oldId]) ?? false
        let newId = taken ? try maxId("recording", db) + 1 : oldId
        let args: StatementArguments = [
            "old": oldId, "new": newId,
            "n": try maxId("notification", db), "b": try maxId("beat", db), "e": try maxId("event", db),
        ]
        try db.execute(sql: """
            INSERT INTO main.recording(id, name, started_at_ms, ended_at_ms, tz_offset_s, device_id, firmware,
                                       battery_start, battery_end, notes, activity, context)
            SELECT :new, name, started_at_ms, ended_at_ms, tz_offset_s, device_id, firmware,
                   battery_start, battery_end, notes, activity, context
            FROM snap.recording WHERE id = :old;
            INSERT INTO main.notification(id, recording_id, received_at_ms, hr_bpm, contact, n_rr)
            SELECT id + :n, :new, received_at_ms, hr_bpm, contact, n_rr
            FROM snap.notification WHERE recording_id = :old;
            INSERT INTO main.beat(id, recording_id, notification_id, idx, rr_1024, rr_ms, t_end_ms_est)
            SELECT id + :b, :new, notification_id + :n, idx, rr_1024, rr_ms, t_end_ms_est
            FROM snap.beat WHERE recording_id = :old;
            INSERT INTO main.event(id, recording_id, at_ms, kind, note, label)
            SELECT id + :e, :new, at_ms, kind, note, label
            FROM snap.event WHERE recording_id = :old;
            INSERT INTO main.motion(recording_id, second_ms, rms_mg, gx_mg, gy_mg, gz_mg, n)
            SELECT :new, second_ms, rms_mg, gx_mg, gy_mg, gz_mg, n
            FROM snap.motion WHERE recording_id = :old;
            """, arguments: args)
        if rec.endedAtMs == nil {
            let last = try RecordingSession.lastActivityMs(newId, db: db) ?? rec.startedAtMs
            try RecordingSession.finish(newId, atMs: last, note: importedNote, db: db)
        }
        guard try Row.fetchAll(db, sql: "PRAGMA main.foreign_key_check").isEmpty else {
            throw SnapshotImportError.brokenReferences
        }
        return newId
    }

    private static func maxId(_ table: String, _ db: Database) throws -> Int64 {
        try Int64.fetchOne(db, sql: "SELECT IFNULL(MAX(id), 0) FROM main.\(table)") ?? 0
    }
}
