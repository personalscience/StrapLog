/// The user-editable fields of a past recording, as typed in the detail screen.
public struct RecordingEdit: Sendable, Equatable {
    public var name: String
    /// `ActivityPreset.id`.
    public var activity: String
    public var notes: String

    public init(name: String, activity: String, notes: String = "") {
        self.name = name
        self.activity = activity
        self.notes = notes
    }

    /// The fields as `recording` has them now.
    public init(_ recording: Recording) {
        self.init(name: recording.name, activity: recording.activity, notes: recording.notes ?? "")
    }

    /// `recording` with these fields, trimmed: a blank name becomes the activity's default
    /// name for the recording's start, blank notes become nil.
    public func applied(to recording: Recording) -> Recording {
        var edited = recording
        let preset = ActivityPreset.named(activity)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.activity = preset.id
        edited.name = name.isEmpty ? preset.defaultName(atMs: recording.startedAtMs, tzOffsetS: recording.tzOffsetS) : name
        edited.notes = notes.isEmpty ? nil : notes
        return edited
    }
}
