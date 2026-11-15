import StrapLogCore
import SwiftUI

/// Home while idle, Recording while a recording is open (including one resumed at launch), and
/// the pacer screen over either while the toolbar's wind button has it shown.
struct RootView: View {
    let model: RecorderModel
    /// The app's guide, shown from the toolbar; nil hides the button.
    var help: (() -> AnyView)?
    /// Training mode on the pacer screen; nil (StrapLog) hides it.
    var training: TrainingRunner?
    @State private var showingHelp = false
    @State private var showingDevice = false

    var body: some View {
        NavigationStack {
            Group {
                if model.pacerScreenShown {
                    PacerScreen(model: model, training: training)
                } else if model.isRecording {
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
                if help != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Guide", systemImage: "questionmark.circle") { showingHelp = true }
                            .accessibilityIdentifier("helpButton")
                    }
                }
            }
        }
        .sheet(isPresented: $showingHelp) { help?() }
        .sheet(isPresented: $showingDevice) {
            DeviceSheet(model: model).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: .init(get: { model.shareRequest != nil }, set: { if !$0 { model.shareHandled() } })) {
            if let url = model.shareRequest {
                ShareSheet(url: url) { model.shareHandled() }
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Something went wrong", isPresented: .init(get: { model.errorMessage != nil },
                                                          set: { if !$0 { model.dismissError() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
