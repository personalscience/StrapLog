public enum RecordingSessionError: Error, Equatable {
    /// `start` while this session is already recording.
    case alreadyRecording
    /// `start` while the database holds an unfinished recording; call `resumeIfOpen` instead.
    case openRecordingExists(id: Int64)
    /// `stop`, `marker` or `snapshot` with nothing recording.
    case notRecording
}
