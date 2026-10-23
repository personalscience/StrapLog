import Charts
import StrapLogCore
import SwiftUI

/// HR, α1 or RR over a window the owner keeps in `viewport`: pinch walks the span, a sideways
/// drag pans back through the recording, the chip picks a span directly, double-tap resets to
/// `defaultSpan`. When panned back, a pill (`followLabel`) returns to the end. The metric tab
/// persists per scene.
struct TrendChart: View {
    let live: LiveMetrics
    let markers: [RecordingEvent]
    let startedAtMs: Int64
    let nowMs: Int64
    @Binding var viewport: ChartViewport
    var height: CGFloat = 200
    var defaultSpan: ChartSpan = .default
    var followLabel = "Live"

    @SceneStorage("chartMetric") private var metric = ChartMetric.heartRate
    @GestureState private var pinch = 1.0
    @GestureState private var dragPx: CGFloat = 0
    @State private var widthPx: CGFloat = 1

    /// α1 axis: room for every band's edge plus a little above rest.
    private static let alpha1Top = 1.5

    var body: some View {
        let committed = viewport.window(nowMs: nowMs, startedAtMs: startedAtMs)
        let shown = viewport
            .zoomed(by: pinch, nowMs: nowMs, startedAtMs: startedAtMs)
            .panned(byMs: panMs(dragPx, in: committed), nowMs: nowMs, startedAtMs: startedAtMs)
        let window = shown.window(nowMs: nowMs, startedAtMs: startedAtMs)
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
                    Picker("Span", selection: $viewport.span) {
                        ForEach(ChartSpan.allCases.sorted(), id: \.self) { Text(Formats.span($0)).tag($0) }
                    }
                } label: {
                    Label(Formats.span(shown.span), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
                .accessibilityIdentifier("chartSpan")
            }
            chart(points: points, window: window, highlightMs: shown.highlightMs)
                .frame(height: height)
                .contentShape(Rectangle())
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widthPx = max($0, 1) }
                .gesture(MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { viewport = viewport.zoomed(by: $0.magnification, nowMs: nowMs, startedAtMs: startedAtMs) })
                .simultaneousGesture(DragGesture(minimumDistance: 12)
                    .updating($dragPx) { value, state, _ in state = Self.sideways(value.translation) }
                    .onEnded {
                        let ms = panMs(Self.sideways($0.translation), in: committed)
                        viewport = viewport.panned(byMs: ms, nowMs: nowMs, startedAtMs: startedAtMs)
                    })
                .onTapGesture(count: 2) { viewport = ChartViewport(span: defaultSpan) }
                .overlay(alignment: .topTrailing) {
                    if shown.isPinned {
                        Button(followLabel, systemImage: "arrow.right.to.line") { viewport.anchorEndMs = nil }
                            .font(.caption.bold())
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.mini)
                            .accessibilityIdentifier("chartFollow")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("trendChart")
        }
    }

    /// A drag's horizontal travel, or 0 when it is mostly vertical (the page is scrolling).
    private static func sideways(_ t: CGSize) -> CGFloat {
        abs(t.width) > abs(t.height) ? t.width : 0
    }

    /// Dragging right by `px` moves back in time by the width that covers.
    private func panMs(_ px: CGFloat, in window: ChartWindow) -> Int64 {
        Int64(-Double(px) * Double(window.endMs - window.startMs) / Double(widthPx))
    }

    @ViewBuilder
    private func chart(points: [TrendPoint], window: ChartWindow, highlightMs: Int64?) -> some View {
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
                let highlighted = marker.atMs == highlightMs
                RuleMark(x: .value("Marker", Date(timeIntervalSince1970: Double(marker.atMs) / 1000)))
                    .foregroundStyle(highlighted ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                    .lineStyle(highlighted ? StrokeStyle(lineWidth: 2) : StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .annotation(position: .top, alignment: window.labelFits(atMs: marker.atMs) ? .leading : .trailing) {
                        Text(marker.markerText).font(.caption2.bold())
                    }
            }
        }
        .chartXScale(domain: start...end)
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: window.axisStrideMinutes)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self),
                   window.labelFits(atMs: Int64(date.timeIntervalSince1970 * 1000)) {
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
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
