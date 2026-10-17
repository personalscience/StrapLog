public enum RecordingSessionError: Error, Equatable {
    /// `start` while this session is already recording.
    case alreadyRecording
    /// `start` while the database holds an unfinished recording; call `resumeIfOpen` instead.
    case openRecordingExists(id: Int64)
    /// `stop`, `marker` or `snapshot` with nothing recording.
    case notRecording
    /// `delete` of the recording being written, or of any unfinished one.
    case cannotDeleteActive
    /// `delete` of an id that is not in the database.
    case noSuchRecording(id: Int64)
}
