/// The time range the chart shows: `span` ending at `endMs` (now, unless panned back). Slices a series to that
/// range and thins it for drawing, so the view only plots what it is handed.
public struct ChartWindow: Sendable, Equatable {
    /// Points the chart draws at most: `Downsample.minMax` keeps two per bucket.
    public static let maxPoints = 400

    public let startMs: Int64
    public let endMs: Int64

    public init(span: ChartSpan, endMs: Int64, startedAtMs: Int64) {
        self.endMs = endMs
        startMs = endMs - span.lengthMs(elapsedMs: endMs - startedAtMs)
    }

    public init(span: ChartSpan, nowMs: Int64, startedAtMs: Int64) {
        self.init(span: span, endMs: nowMs, startedAtMs: startedAtMs)
    }

    /// Whole-minute steps for x-axis ticks: labels are hour:minute, never seconds, so they fit.
    static let axisStepsMinutes = [1, 2, 5, 10, 15, 30, 60, 120, 180, 360, 720]
    /// Ticks the x-axis aims for at most.
    public static let maxAxisTicks = 4

    /// Minutes between x-axis ticks: the smallest step that keeps `maxAxisTicks` or fewer.
    public var axisStrideMinutes: Int {
        let minutes = Double(endMs - startMs) / 60_000
        return Self.axisStepsMinutes.first { minutes / Double($0) <= Double(Self.maxAxisTicks) }
            ?? Self.axisStepsMinutes.last!
    }

    /// Share of the width a label needs right of its anchor: closer to the end it would truncate.
    static let labelWidth = 0.15

    /// Whether a label starting at `atMs` (an axis tick or a marker) fits before the right edge.
    public func labelFits(atMs: Int64) -> Bool {
        Double(endMs - atMs) >= Double(endMs - startMs) * Self.labelWidth
    }

    /// The points inside the window (`series` oldest first), at most `maxPoints` of them.
    public func visible(_ series: [TrendPoint]) -> [TrendPoint] {
        Downsample.minMax(Array(series[slice(series)]), buckets: Self.maxPoints / 2)
    }

    /// Markers inside the window.
    public func visible(_ markers: [RecordingEvent]) -> [RecordingEvent] {
        markers.filter { $0.atMs >= startMs && $0.atMs <= endMs }
    }

    func slice(_ series: [TrendPoint]) -> Range<Int> {
        lowerBound(series, startMs)..<lowerBound(series, endMs + 1)
    }

    /// First index whose time is at or past `ms` (binary search).
    private func lowerBound(_ series: [TrendPoint], _ ms: Int64) -> Int {
        var (lo, hi) = (0, series.count)
        while lo < hi {
            let mid = (lo + hi) / 2
            if series[mid].atMs < ms { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}
