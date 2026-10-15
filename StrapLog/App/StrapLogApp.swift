import StrapLogCore
import SwiftUI

@main
struct StrapLogApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            switch appDelegate.dependencies {
            case .success(let deps):
                RootView(model: deps.model)
                    .onChange(of: scenePhase, initial: true) { _, phase in
                        guard let phase = AppPhase(phase) else { return }
                        Task { await deps.model.appPhase(phase) }
                    }
            case .failure(let error):
                ContentUnavailableView("StrapLog could not start", systemImage: "exclamationmark.triangle",
                                       description: Text(String(describing: error)))
            }
        }
    }
}
