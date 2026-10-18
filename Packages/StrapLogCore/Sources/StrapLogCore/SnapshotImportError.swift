/// Why `SnapshotImport` skipped a file.
enum SnapshotImportError: Error {
    /// No `meta.format = 'straplog'`: not a StrapLog export.
    case notASnapshot
    /// Written by a newer app with migrations this one does not know.
    case newerSchema
    /// The copied rows failed `foreign_key_check`.
    case brokenReferences
}
