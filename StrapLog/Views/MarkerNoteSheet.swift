import SwiftUI

/// A free-text marker: type one, or pick a note used before. Typing narrows the list; a row logs
/// its note, and its arrow copies the note into the field to edit. Done logs exactly what was typed.
struct MarkerNoteSheet: View {
    let suggestions: (String) -> [String]
    let add: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                let matches = suggestions(note)
                if !matches.isEmpty {
                    Section(note.isEmpty ? "Recent" : "Matches") {
                        ForEach(matches, id: \.self, content: row)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            // Pinned, because the list can run to 100 rows.
            .safeAreaInset(edge: .top) {
                TextField("Note", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .accessibilityIdentifier("markerNote")
                    .padding()
                    .background(.bar)
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

    private func row(_ recent: String) -> some View {
        HStack {
            Button { log(recent) } label: {
                Text(recent).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
            }
            .accessibilityIdentifier("recentNote-\(recent)")
            Button {
                note = recent
                focused = true
            } label: {
                Image(systemName: "arrow.up.left").frame(minWidth: 44, minHeight: 44).contentShape(.rect)
            }
            .accessibilityLabel("Edit \(recent)")
            .accessibilityIdentifier("copyNote-\(recent)")
        }
        .buttonStyle(.borderless)
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
