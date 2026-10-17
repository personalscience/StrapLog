import Foundation
import GRDB

/// Single-file export of one recording for Files / AirDrop / the skills.
/// `VACUUM INTO` a temp file, delete every other recording from it (foreign keys cascade) and
/// vacuum again, switch it to rollback journaling so readers never create `-wal`/`-shm`
/// sidecars, then atomically replace the destination. One recording per file means deleting a
/// recording and its file leaves no copy of it in iCloud Drive.
///
/// The partial file lives in a replacement directory on the destination's volume, outside
/// the destination folder, so iCloud Drive never uploads it; the swap is file-coordinated so
/// the iCloud daemon sees one complete write.
public enum Snapshot {
    public static func write(_ database: StrapLogDatabase, recordingId: Int64, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let scratch = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: url, create: true)
        defer { try? fm.removeItem(at: scratch) }
        let tmp = scratch.appendingPathComponent(url.lastPathComponent)

        try database.writer.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM INTO ?", arguments: [tmp.path])
        }
        let copy = try DatabaseQueue(path: tmp.path)
        try copy.writeWithoutTransaction { db in
            try db.execute(sql: "DELETE FROM recording WHERE id != ?", arguments: [recordingId])
            try db.execute(sql: "VACUUM")
            try db.execute(sql: "PRAGMA journal_mode = DELETE")
        }
        try copy.close()

        var coordinationError: NSError?
        var moveError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing,
                                       error: &coordinationError) { target in
            do {
                if fm.fileExists(atPath: target.path) {
                    _ = try fm.replaceItemAt(target, withItemAt: tmp)
                } else {
                    try fm.moveItem(at: tmp, to: target)
                }
            } catch {
                moveError = error
            }
        }
        if let error = coordinationError ?? moveError { throw error }
    }

    /// File-coordinated delete, so iCloud Drive removes it everywhere. A missing file is fine.
    public static func remove(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        var coordinationError: NSError?
        var removeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting,
                                       error: &coordinationError) { target in
            do { try fm.removeItem(at: target) } catch { removeError = error }
        }
        if let error = coordinationError ?? removeError { throw error }
    }

    /// `YYMMDD-HHMM-<name>.sqlite` in the recording's local time; name sanitised for file systems.
    public static func fileName(for recording: Recording) -> String {
        let local = Date(timeIntervalSince1970: Double(recording.startedAtMs) / 1000
                         + Double(recording.tzOffsetS))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyMMdd-HHmm"
        let stamp = f.string(from: local)
        let safe = String(recording.name.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
        return safe.isEmpty ? "\(stamp).sqlite" : "\(stamp)-\(safe).sqlite"
    }
}
