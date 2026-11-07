import StrapLogCore
import SwiftUI

/// Idle screen: live HR to check the strap, activity picker (with a wake time for overnight
/// presets), optional name, Start, the summary of the recording that just stopped, and past
/// recordings (tap for detail; swipe to delete, after a confirmation).
struct HomeView: View {
    let model: RecorderModel
    @AppStorage(StartPreferences.activityKey) private var activity = ActivityPreset.other.id
    @AppStorage(StartPreferences.stopAtWakeKey) private var stopAtWake = StartPreferences.defaultStopAtWake
    @AppStorage(StartPreferences.wakeAtKey) private var wakeAt = StartPreferences.defaultWakeAt
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
                if ActivityPreset.named(activity).overnight {
                    Toggle("Stop at wake time", isOn: $stopAtWake)
                        .accessibilityIdentifier("stopAtWake")
                    if stopAtWake {
                        DatePicker("Wake at", selection: wakeTime, displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("wakeAt")
                    }
                }
                TextField("Name (optional)", text: $name)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sessionName")
                Button {
                    let plan = StartPreferences.plan(stopAtWake: stopAtWake, wakeAt: wakeAt)
                    Task { await model.start(ActivityPreset.named(activity), name: name, plan: plan) }
                } label: {
                    Label("Start recording", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("startButton")
            }
            if let finished = model.lastFinished {
                Section("Last recording") {
                    NavigationLink(value: finished.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(finished.recording.name).font(.headline)
                            SessionSummaryCard(summary: finished.summary)
                        }
                    }
                    .accessibilityIdentifier("lastFinished")
                }
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
                    NavigationLink(value: summary.id) {
                        RecordingRow(summary: summary)
                    }
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

    private var wakeTime: Binding<Date> {
        Binding(get: { Date(timeIntervalSinceReferenceDate: wakeAt) },
                set: { wakeAt = $0.timeIntervalSinceReferenceDate })
    }
}
