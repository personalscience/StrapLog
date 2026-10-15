import StrapLogCore
import SwiftUI

/// One-tap `a` `b` `c` `end` markers plus a free-text marker.
struct MarkerBar: View {
    static let quickMarkers = ["a", "b", "c", "end"]

    let model: RecorderModel
    @State private var note = ""

    var body: some View {
        HStack {
            ForEach(Self.quickMarkers, id: \.self) { marker in
                Button(marker) { Task { await model.marker(marker) } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("marker-\(marker)")
            }
        }
        HStack {
            TextField("Note", text: $note)
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
