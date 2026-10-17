import StrapLogCore
import SwiftUI

/// Idle screen: live HR to check the strap, activity picker, optional name, Start, and past
/// recordings (swipe to delete, after a confirmation).
struct HomeView: View {
    let model: RecorderModel
    @AppStorage("activity") private var activity = ActivityPreset.other.id
    @State private var name = ""
    @State private var pendingDelete: RecordingSummary?

    var body: some View {
        List {
            Section {
                HeartRateTile(heartRate: model.heartRate, contact: model.contact)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                Picker("Activity", selection: $activity) {
                    ForEach(ActivityPreset.all) { preset in
                        Label(preset.title, systemImage: preset.systemImage).tag(preset.id)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("activityPicker")
                TextField("Name (optional)", text: $name)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sessionName")
                Button {
                    Task { await model.start(ActivityPreset.named(activity), name: name) }
                } label: {
                    Label("Start recording", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("startButton")
            }
            if let snapshot = model.lastSnapshot {
                Section("Last export") {
                    Text(Formats.exportLocation(snapshot))
                        .font(.footnote.monospaced())
                        .accessibilityIdentifier("lastSnapshot")
                }
            }
            Section("Recordings") {
                ForEach(model.recordings) { summary in
                    RecordingRow(summary: summary)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = summary }
                        }
                }
            }
        }
        .confirmationDialog("Delete recording?", isPresented: .init(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingDelete) { summary in
            Button("Delete \(summary.name.isEmpty ? "Untitled" : summary.name)", role: .destructive) {
                Task { await model.delete(summary) }
            }
        } message: { _ in
            Text("Removes its beats from this iPhone and its export from iCloud Drive. This cannot be undone.")
        }
    }
}
