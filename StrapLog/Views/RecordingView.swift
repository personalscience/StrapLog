import StrapLogCore
import SwiftUI

/// Live screen while recording: HR and α1 up top, the trend chart, markers in the thumb zone,
/// then pacer and Stop. Diagnostics live in the device sheet behind the toolbar heart.
struct RecordingView: View {
    let model: RecorderModel
    @State private var showingPacer = false
    @State private var confirmingStop = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MetricsHero(model: model, nowMs: nowMs)
                    TrendChart(live: model.live, markers: model.markers,
                               startedAtMs: model.activeRecording?.startedAtMs ?? nowMs, nowMs: nowMs)
                    MarkerBar(model: model, nowMs: nowMs)
                    if showingPacer || model.pacer != nil {
                        PacerSection(model: model)
                    }
                    HStack {
                        if model.pacer == nil, model.activePreset.pacer {
                            Button(showingPacer ? "Hide pacer" : "Pacer", systemImage: "wind") {
                                showingPacer.toggle()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("pacerToggle")
                        }
                        Spacer()
                        Button("Stop…", systemImage: "stop.circle", role: .destructive) { confirmingStop = true }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("stopButton")
                    }
                }
                .padding()
            }
        }
        .confirmationDialog("Stop this recording and export it?", isPresented: $confirmingStop,
                            titleVisibility: .visible) {
            Button("Stop and export", role: .destructive) { Task { await model.stop() } }
                .accessibilityIdentifier("confirmStop")
        }
    }
}
