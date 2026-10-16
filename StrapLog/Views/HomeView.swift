import StrapLogCore
import SwiftUI

/// Idle screen: live HR to check the strap, name field, Start, and past recordings.
struct HomeView: View {
    let model: RecorderModel
    @State private var name = ""

    var body: some View {
        List {
            Section {
                HeartRateTile(heartRate: model.heartRate, contact: model.contact)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                TextField("Session name", text: $name)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sessionName")
                Button {
                    Task { await model.start(name: name) }
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
                ForEach(model.recordings) { RecordingRow(summary: $0) }
            }
        }
    }
}
