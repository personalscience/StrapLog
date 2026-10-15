import StrapLogCore
import SwiftUI

/// Home while idle, Recording while a recording is open (including one resumed at launch).
struct RootView: View {
    let model: RecorderModel
    @State private var showingHelp = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isRecording {
                    RecordingView(model: model)
                } else {
                    HomeView(model: model)
                }
            }
            .navigationTitle("StrapLog")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guide", systemImage: "questionmark.circle") { showingHelp = true }
                        .accessibilityIdentifier("helpButton")
                }
            }
        }
        .sheet(isPresented: $showingHelp) { HelpView(blocks: Guide.blocks) }
        .alert("Something went wrong", isPresented: .init(get: { model.errorMessage != nil },
                                                          set: { if !$0 { model.dismissError() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
