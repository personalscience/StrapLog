import StrapLogCore
import SwiftUI

/// Live screen while recording: HR and α1 up top, the trend chart, markers in the thumb zone,
/// then Stop. Overnight presets add a line saying how the night will end. In landscape the numbers sit left of the chart. Diagnostics live in the
/// device sheet behind the toolbar heart.
struct RecordingView: View {
    let model: RecorderModel
    @State private var confirmingStop = false
    @State private var confirmingDiscard = false
    @SceneStorage("chartViewport") private var viewport = ChartViewport()
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let plan = model.overnightPlan {
                        Text(Formats.overnightPlan(plan))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("overnightPlan")
                    }
                    if verticalSizeClass == .compact {
                        // Landscape: numbers left, chart right, markers and controls along the bottom.
                        HStack(alignment: .top, spacing: 16) {
                            MetricsHero(model: model, nowMs: nowMs)
                                .frame(maxWidth: 340)
                            chart(nowMs: nowMs, height: 150)
                        }
                    } else {
                        MetricsHero(model: model, nowMs: nowMs)
                        chart(nowMs: nowMs, height: 200)
                    }
                    MarkerBar(model: model, nowMs: nowMs)
                    controls
                }
                .padding()
            }
        }
        .confirmationDialog("Stop this recording?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Save") { Task { await model.stop(.save) } }
                .accessibilityIdentifier("confirmStop")
            Button("Save and share") { Task { await model.stop(.share) } }
                .accessibilityIdentifier("confirmStopShare")
            Button("Delete", role: .destructive) { confirmingDiscard = true }
                .accessibilityIdentifier("confirmStopDelete")
            Button("Keep recording", role: .cancel) {}
        } message: {
            Text("Save exports it to iCloud Drive.")
        }
        .alert("Delete this recording?", isPresented: $confirmingDiscard) {
            Button("Delete", role: .destructive) { Task { await model.stop(.discard) } }
                .accessibilityIdentifier("confirmDiscard")
            Button("Keep recording", role: .cancel) {}
        } message: {
            Text("Stops it and removes its beats from this iPhone. Nothing is exported. This cannot be undone.")
        }
    }

    private func chart(nowMs: Int64, height: CGFloat) -> some View {
        TrendChart(live: model.live, markers: model.markers,
                   startedAtMs: model.activeRecording?.startedAtMs ?? nowMs, nowMs: nowMs,
                   viewport: $viewport, height: height)
    }

    private var controls: some View {
        HStack {
            Spacer()
            Button("Stop…", systemImage: "stop.circle", role: .destructive) { confirmingStop = true }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("stopButton")
        }
    }
}
