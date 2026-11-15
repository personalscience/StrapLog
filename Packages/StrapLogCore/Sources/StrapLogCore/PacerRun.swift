/// One stretch of the breathing pacer inside a recording, read back from its `pacer_start` and
/// `pacer_stop` events. Mirrors `export.pacer_sessions` in straplog-py, which leaves an
/// unstopped run's stop empty; here it ends where the next one starts, or at the recording's end.
public struct PacerRun: Sendable, Equatable {
    public let stamp: PacerStamp
    /// The `pacer_start` event.
    public let startMs: Int64
    /// The `pacer_stop`, else the next `pacer_start`, else the end of the recording.
    public let stopMs: Int64

    public init(stamp: PacerStamp, startMs: Int64, stopMs: Int64) {
        self.stamp = stamp
        self.startMs = startMs
        self.stopMs = stopMs
    }

    /// When breath 0 began: the stamp's `t0`, or the start for a pre-1.2 note.
    public var originMs: Int64 { stamp.t0Ms ?? startMs }

    public var periodMs: Double { 60_000 / stamp.breathsPerMinute }

    /// The runs in `events` (any order; other kinds ignored), oldest first. A start whose note
    /// does not parse is skipped, and so is a run with no length.
    public static func runs(_ events: [RecordingEvent], endMs: Int64) -> [PacerRun] {
        let pacer = events.filter { $0.kind == .pacerStart || $0.kind == .pacerStop }
            .sorted { ($0.atMs, $0.id ?? 0) < ($1.atMs, $1.id ?? 0) }
        var out: [PacerRun] = []
        var open: (stamp: PacerStamp, atMs: Int64)?
        func close(atMs: Int64) {
            if let o = open, atMs > o.atMs { out.append(PacerRun(stamp: o.stamp, startMs: o.atMs, stopMs: atMs)) }
            open = nil
        }
        for event in pacer {
            if event.kind == .pacerStop {
                close(atMs: event.atMs)
            } else {
                close(atMs: event.atMs)
                open = PacerStamp(note: event.note ?? "").map { ($0, event.atMs) }
            }
        }
        close(atMs: endMs)
        return out
    }
}
