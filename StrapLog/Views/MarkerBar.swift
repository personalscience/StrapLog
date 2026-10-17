import StrapLogCore
import SwiftUI

/// One-tap markers from the recording's preset (`ActivityPreset.markers`) plus a free-text marker.
struct MarkerBar: View {
    let model: RecorderModel
    let nowMs: Int64
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Formats.marker(model.lastMarker, count: model.markerCount, nowMs: nowMs))
                .font(.callout.monospacedDigit())
                .foregroundStyle(model.lastMarker == nil ? .secondary : .primary)
                .accessibilityIdentifier("lastMarker")
                .sensoryFeedback(.impact, trigger: model.markerCount)
            HStack {
                ForEach(model.activePreset.markers, id: \.self) { marker in
                    Button { Task { await model.marker(label: marker) } } label: {
                        Text(Formats.markerButton(marker)).font(.title3.bold())
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("marker-\(marker)")
                }
            }
            HStack {
                TextField("Note", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("markerNote")
                Button("Add") {
                    let text = note
                    note = ""
                    Task { await model.marker(note: text) }
                }
                .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
