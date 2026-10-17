import GRDB

/// Everything the recording detail screen shows for one past recording, read in one pass.
public struct RecordingDetail: Sendable {
    public var recording: Recording
    /// Oldest first.
    public var markers: [RecordingEvent]
    public var summary: SessionSummary
    /// The beats replayed through the live analysis, so the detail chart draws what the
    /// recording screen drew. Keeps the whole recording, however long.
    public var live: LiveMetrics

    public var id: Int64 { recording.id ?? 0 }

    /// Where the chart ends: the stop, or the last beat of an open recording.
    public var endMs: Int64 {
        recording.endedAtMs ?? live.rrHistory.last?.atMs ?? recording.startedAtMs
    }

    /// Nil if there is no recording `id`.
    public static func load(_ id: Int64, db: Database) throws -> RecordingDetail? {
        guard let recording = try Recording.fetchOne(db, key: id) else { return nil }
        let beats = try Beat.filter(sql: "recording_id = ?", arguments: [id]).order(sql: "id").fetchAll(db)
        let markers = try RecordingEvent.fetchAll(db, sql: """
            SELECT * FROM event WHERE recording_id = ? AND kind = 'marker' ORDER BY at_ms, id
            """, arguments: [id])
        var live = LiveMetrics(historySpanMs: .max)
        for beat in beats { live.add(beat) }
        return RecordingDetail(recording: recording, markers: markers,
                               summary: SessionSummary(recording, beats: beats,
                                                       coverage: try Coverage.of(recording: id, db: db)),
                               live: live)
    }
}
