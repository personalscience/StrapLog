import StrapLogCore
import SwiftUI

/// Add, rename, delete and reorder one activity's marker labels. Saving hands the list to
/// `MarkerPresets.setMarkers`, which trims it and drops blanks and repeats.
struct MarkerPresetEditor: View {
    let preset: ActivityPreset
    let isEdited: Bool
    let save: ([String]) -> Void
    let reset: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [Row]
    @State private var newLabel = ""

    init(preset: ActivityPreset, isEdited: Bool, save: @escaping ([String]) -> Void, reset: @escaping () -> Void) {
        self.preset = preset
        self.isEdited = isEdited
        self.save = save
        self.reset = reset
        _rows = State(initialValue: preset.markers.map(Row.init))
    }

    /// A label being edited, with an id that survives typing.
    private struct Row: Identifiable {
        let id = UUID()
        var text: String
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($rows) { $row in
                        TextField("Label", text: $row.text)
                    }
                    .onDelete { rows.remove(atOffsets: $0) }
                    .onMove { rows.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        TextField("New label", text: $newLabel)
                            .onSubmit(add)
                            .accessibilityIdentifier("newMarkerLabel")
                        Button("Add", systemImage: "plus.circle.fill", action: add)
                            .labelStyle(.iconOnly)
                            .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("Labels are stored in each marker's label column, so analysis skills can key off them.")
                }
                if isEdited {
                    Section {
                        Button("Restore \(preset.title) defaults", role: .destructive) {
                            reset()
                            dismiss()
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("\(preset.title) markers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(rows.map(\.text) + [newLabel])
                        dismiss()
                    }
                    .accessibilityIdentifier("saveMarkers")
                }
            }
        }
    }

    private func add() {
        rows.append(Row(text: newLabel))
        newLabel = ""
    }
}
