import Foundation

/// File-coordinated writes into the export folder, so the iCloud daemon sees each change as
/// one complete write (or one delete) and never uploads a partial file.
public enum CoordinatedFile {
    /// Atomically moves the finished file `source` to `target`, replacing any file there.
    public static func replace(_ target: URL, with source: URL) throws {
        let fm = FileManager.default
        try coordinate(target, .forReplacing) { url in
            if fm.fileExists(atPath: url.path) {
                _ = try fm.replaceItemAt(url, withItemAt: source)
            } else {
                try fm.moveItem(at: source, to: url)
            }
        }
    }

    /// Writes `data` to `target` via a temp file on the same volume, then `replace`.
    public static func write(_ data: Data, to target: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let scratch = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: target, create: true)
        defer { try? fm.removeItem(at: scratch) }
        let tmp = scratch.appendingPathComponent(target.lastPathComponent)
        try data.write(to: tmp)
        try replace(target, with: tmp)
    }

    /// Deletes `target` everywhere iCloud Drive has it. A missing file is fine.
    public static func remove(at target: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: target.path) else { return }
        try coordinate(target, .forDeleting) { try fm.removeItem(at: $0) }
    }

    /// Copies `source` to `destination` under a coordinated read, so an iCloud file is
    /// read whole and never mid-update.
    public static func copy(_ source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var bodyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges,
                                       error: &coordinationError) { url in
            do { try FileManager.default.copyItem(at: url, to: destination) } catch { bodyError = error }
        }
        if let error = coordinationError ?? bodyError { throw error }
    }

    private static func coordinate(_ target: URL, _ options: NSFileCoordinator.WritingOptions,
                                   _ body: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var bodyError: Error?
        NSFileCoordinator().coordinate(writingItemAt: target, options: options,
                                       error: &coordinationError) { url in
            do { try body(url) } catch { bodyError = error }
        }
        if let error = coordinationError ?? bodyError { throw error }
    }
}
