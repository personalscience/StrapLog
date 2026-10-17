import StrapLogCore
import SwiftUI

/// The thumb-zone marker row: one large button per label of the recording's preset
/// (`RecorderModel.activePreset`), then `+` for a free-text note. Long-press edits the labels.
struct MarkerBar: View {
    let model: RecorderModel
    let nowMs: Int64
    @State private var addingNote = false
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Formats.marker(model.lastMarker, count: model.markerCount, nowMs: nowMs))
                .font(.callout.monospacedDigit())
                .foregroundStyle(model.lastMarker == nil ? .secondary : .primary)
                .accessibilityIdentifier("lastMarker")
                .sensoryFeedback(.impact, trigger: model.markerCount)
            HStack {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(model.activePreset.markers, id: \.self) { marker in
                            Button { Task { await model.marker(label: marker) } } label: {
                                Text(Formats.markerButton(marker)).font(.title3.bold())
                                    .lineLimit(1)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityIdentifier("marker-\(marker)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                // Pinned outside the scroll so a long bar never hides it.
                Button { addingNote = true } label: {
                    Image(systemName: "plus").font(.title3.bold())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Add note")
                .accessibilityIdentifier("markerAdd")
            }
            .buttonStyle(.bordered)
            .contextMenu {
                Button("Edit markers…", systemImage: "pencil") { editing = true }
            }
        }
        .sheet(isPresented: $addingNote) {
            MarkerNoteSheet(recentNotes: model.recentNotes) { note in
                Task { await model.marker(note: note) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $editing) {
            MarkerPresetEditor(preset: model.activePreset,
                               isEdited: model.markerPresets.isEdited(model.activePreset.id),
                               save: { labels in Task { await model.setMarkers(labels, for: model.activePreset) } },
                               reset: { Task { await model.resetMarkers(for: model.activePreset) } })
        }
    }
}
