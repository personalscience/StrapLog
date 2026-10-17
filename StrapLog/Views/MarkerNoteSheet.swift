import SwiftUI

/// A free-text marker: type one, or tap a recent note to log it again.
struct MarkerNoteSheet: View {
    let recentNotes: [String]
    let add: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Note", text: $note)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(submit)
                        .accessibilityIdentifier("markerNote")
                }
                if !recentNotes.isEmpty {
                    Section("Recent") {
                        ForEach(recentNotes, id: \.self) { recent in
                            Button(recent) { log(recent) }
                                .accessibilityIdentifier("recentNote-\(recent)")
                        }
                    }
                }
            }
            .navigationTitle("Add note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: submit)
                        .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("markerNoteAdd")
                }
            }
            .onAppear { focused = true }
        }
    }

    private func submit() {
        guard !note.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        log(note)
    }

    private func log(_ text: String) {
        add(text)
        dismiss()
    }
}
