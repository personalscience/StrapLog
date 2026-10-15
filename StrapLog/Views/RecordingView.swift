import StrapLogCore
import SwiftUI

/// Live screen while recording: HR, elapsed time, beat count, gaps, markers, Stop.
struct RecordingView: View {
    let model: RecorderModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            List {
                Section {
                    Text(model.activeRecording?.name ?? "")
                        .font(.headline)
                    LinkStatusRow(model: model)
                }
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.heartRate.map(String.init) ?? "--")
                            .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                            .accessibilityIdentifier("heartRate")
                        Text("bpm").foregroundStyle(.secondary)
                    }
                    LabeledContent("Elapsed",
                                   value: Formats.elapsed(ms: nowMs - (model.activeRecording?.startedAtMs ?? nowMs)))
                    LabeledContent("Beats", value: "\(model.beatCount)")
                        .accessibilityIdentifier("beatCount")
                    LabeledContent("Since last notification",
                                   value: model.lastHeardAtMs.map { Formats.gap(ms: nowMs - $0) } ?? "--")
                    LabeledContent("Longest gap", value: Formats.gap(ms: model.longestGapMs))
                }
                Section("Markers") {
                    MarkerBar(model: model)
                }
                Section {
                    Button(role: .destructive) {
                        Task { await model.stop() }
                    } label: {
                        Label("Stop and export", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("stopButton")
                }
            }
        }
    }
}
