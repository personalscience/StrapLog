import StrapLogCore
import SwiftUI

/// One-tap `a` `b` `c` `end` markers plus a free-text marker.
struct MarkerBar: View {
    static let quickMarkers = ["a", "b", "c", "end"]

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
                ForEach(Self.quickMarkers, id: \.self) { marker in
                    Button { Task { await model.marker(marker) } } label: {
                        Text(marker).font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 44)
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
                    Task { await model.marker(text) }
                }
                .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
