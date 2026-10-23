import StrapLogCore
import SwiftUI

/// Home while idle, Recording while a recording is open (including one resumed at launch).
struct RootView: View {
    let model: RecorderModel
    @State private var showingHelp = false
    @State private var showingDevice = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isRecording {
                    RecordingView(model: model)
                } else {
                    HomeView(model: model)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int64.self) { RecordingDetailView(model: model, id: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HeartLinkButton(link: model.link) { showingDevice = true }
                }
                ToolbarItem(placement: .principal) {
                    RecordingTitle(recording: model.activeRecording)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PacerToggle(model: model)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guide", systemImage: "questionmark.circle") { showingHelp = true }
                        .accessibilityIdentifier("helpButton")
                }
            }
        }
        .sheet(isPresented: $showingHelp) { HelpView(book: Guide.book) }
        .sheet(isPresented: $showingDevice) {
            DeviceSheet(model: model).presentationDetents([.medium, .large])
        }
        .alert("Something went wrong", isPresented: .init(get: { model.errorMessage != nil },
                                                          set: { if !$0 { model.dismissError() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
