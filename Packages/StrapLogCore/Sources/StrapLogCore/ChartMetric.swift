/// What the live chart plots. Raw values persist the chosen tab across launches.
public enum ChartMetric: String, CaseIterable, Sendable {
    case heartRate = "hr", alpha1, rr

    /// This metric's points inside `window`, ready to draw.
    public func points(in window: ChartWindow, of live: LiveMetrics) -> [TrendPoint] {
        switch self {
        case .rr:
            window.visible(live.rrHistory)
        case .heartRate:
            // Convert only the visible beats, not the whole recording.
            window.visible(Array(live.rrHistory[window.slice(live.rrHistory)])
                .map { TrendPoint(atMs: $0.atMs, value: 60_000 / $0.value) })
        case .alpha1:
            window.visible(live.alpha1History)
        }
    }
}
