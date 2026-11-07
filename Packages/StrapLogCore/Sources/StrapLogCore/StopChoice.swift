/// What the user wants done with a recording as they stop it.
public enum StopChoice: Sendable {
    /// Export it, as every stop always has.
    case save
    /// Export it, then hand the export to the share sheet (`RecorderModel.shareRequest`).
    case share
    /// Stop it and delete it: its rows and its export.
    case discard
}
