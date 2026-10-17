import Foundation

/// One row of `index.json`: enough to choose a recording without opening its file.
public struct ExportIndexEntry: Codable, Sendable, Equatable {
    /// Snapshot file name in the same folder.
    public var file: String
    public var id: Int64
    public var name: String
    public var activity: String
    public var startedAtMs: Int64
    /// Absent while the recording is still being written.
    public var endedAtMs: Int64?
    public var tzOffsetS: Int
    /// Start in local time with its offset, e.g. `2026-10-16T22:31:00-07:00`.
    public var startedLocal: String
    public var durationMs: Int64?
    public var beats: Int
    /// `Coverage.fraction`, rounded to 4 places.
    public var coverage: Double
    /// Marker labels in time order.
    public var labels: [String]

    enum CodingKeys: String, CodingKey {
        case file, id, name, activity, beats, coverage, labels
        case startedAtMs = "started_at_ms", endedAtMs = "ended_at_ms", tzOffsetS = "tz_offset_s"
        case startedLocal = "started_local", durationMs = "duration_ms"
    }

    public init(_ recording: Recording, beats: Int, coverage: Coverage, labels: [String]) {
        file = Snapshot.fileName(for: recording)
        id = recording.id ?? 0
        name = recording.name
        activity = recording.activity
        startedAtMs = recording.startedAtMs
        endedAtMs = recording.endedAtMs
        tzOffsetS = recording.tzOffsetS
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: recording.tzOffsetS)
        startedLocal = f.string(from: Date(timeIntervalSince1970: Double(recording.startedAtMs) / 1000))
        durationMs = recording.endedAtMs.map { $0 - recording.startedAtMs }
        self.beats = beats
        self.coverage = (coverage.fraction * 10_000).rounded() / 10_000
        self.labels = labels
    }
}
