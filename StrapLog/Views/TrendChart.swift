import Charts
import StrapLogCore
import SwiftUI

/// HR, α1 or RR over a pinch-zoomable span ending at `nowMs`, with markers as labelled rules.
/// Double-tap resets to `defaultSpan`; the chip picks a span directly. Tab and span persist per
/// scene, the span under `spanKey` so a past recording's chart keeps its own.
struct TrendChart: View {
    let live: LiveMetrics
    let markers: [RecordingEvent]
    let startedAtMs: Int64
    let nowMs: Int64
    let height: CGFloat
    private let defaultSpan: ChartSpan

    @SceneStorage("chartMetric") private var metric = ChartMetric.heartRate
    @SceneStorage private var span: ChartSpan
    @GestureState private var pinch = 1.0

    init(live: LiveMetrics, markers: [RecordingEvent], startedAtMs: Int64, nowMs: Int64, height: CGFloat = 200,
         spanKey: String = "chartSpan", defaultSpan: ChartSpan = .default) {
        self.live = live
        self.markers = markers
        self.startedAtMs = startedAtMs
        self.nowMs = nowMs
        self.height = height
        self.defaultSpan = defaultSpan
        _span = SceneStorage(wrappedValue: defaultSpan, spanKey)
    }

    /// α1 axis: room for every band's edge plus a little above rest.
    private static let alpha1Top = 1.5

    var body: some View {
        let elapsedMs = nowMs - startedAtMs
        let shown = span.zoomed(by: pinch, elapsedMs: elapsedMs)
        let window = ChartWindow(span: shown, nowMs: nowMs, startedAtMs: startedAtMs)
        let points = metric.points(in: window, of: live)
        VStack(spacing: 8) {
            HStack {
                Picker("Metric", selection: $metric) {
                    ForEach(ChartMetric.allCases, id: \.self) { Text(Formats.metric($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .accessibilityIdentifier("chartMetric")
                Spacer()
                Menu {
                    Picker("Span", selection: $span) {
                        ForEach(ChartSpan.allCases.sorted(), id: \.self) { Text(Formats.span($0)).tag($0) }
                    }
                } label: {
                    Label(Formats.span(shown), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
                .accessibilityIdentifier("chartSpan")
            }
            chart(points: points, window: window)
                .frame(height: height)
                .contentShape(Rectangle())
                .gesture(MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { span = span.zoomed(by: $0.magnification, elapsedMs: elapsedMs) })
                .onTapGesture(count: 2) { span = defaultSpan }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("trendChart")
        }
    }

    @ViewBuilder
    private func chart(points: [TrendPoint], window: ChartWindow) -> some View {
        let start = Date(timeIntervalSince1970: Double(window.startMs) / 1000)
        let end = Date(timeIntervalSince1970: Double(window.endMs) / 1000)
        let shownMarkers = window.visible(markers)
        Chart {
            if metric == .alpha1 {
                ForEach(Alpha1Band.allCases, id: \.self) { band in
                    RectangleMark(xStart: .value("Start", start), xEnd: .value("End", end),
                                  yStart: .value("Low", band.lowerBound),
                                  yEnd: .value("High", min(band.upperBound, Self.alpha1Top)))
                        .foregroundStyle(band.color.opacity(0.12))
                }
                ForEach([Alpha1Band.easy, .moderate], id: \.self) { band in
                    RuleMark(y: .value("Threshold", band.lowerBound))
                        .foregroundStyle(band.color.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            ForEach(points.indices, id: \.self) { i in
                LineMark(x: .value("Time", points[i].date), y: .value(Formats.axis(metric), points[i].value))
                    .foregroundStyle(metric == .alpha1 ? Color.primary : Color.red)
            }
            if metric == .alpha1 {
                ForEach(points.indices, id: \.self) { i in
                    PointMark(x: .value("Time", points[i].date), y: .value("α1", points[i].value))
                        .symbolSize(16)
                        .foregroundStyle(Alpha1Band(alpha1: points[i].value).color)
                }
            }
            ForEach(shownMarkers.indices, id: \.self) { i in
                let marker = shownMarkers[i]
                RuleMark(x: .value("Marker", Date(timeIntervalSince1970: Double(marker.atMs) / 1000)))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .annotation(position: .top, alignment: .leading) {
                        Text(marker.markerText).font(.caption2.bold())
                    }
            }
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: metric == .alpha1
                     ? .automatic(includesZero: true)
                     : .automatic(includesZero: false))
        .chartYAxisLabel(Formats.axis(metric))
        .overlay {
            if points.count < 2 {
                Text(Formats.chartEmpty(metric))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
