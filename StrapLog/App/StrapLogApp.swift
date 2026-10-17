import StrapLogCore
import SwiftUI

@main
struct StrapLogApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            switch appDelegate.launcher {
            case .success(let launcher):
                Group {
                    if let model = launcher.model {
                        RootView(model: model)
                            .onChange(of: scenePhase, initial: true) { _, phase in
                                guard let phase = AppPhase(phase) else { return }
                                Task { await model.appPhase(phase) }
                            }
                    } else {
                        ContentUnavailableView("StrapLog could not open its database", systemImage: "lock",
                                               description: Text(launcher.openError.map { String(describing: $0) } ?? ""))
                    }
                }
                // Retries a database that could not open in a launch before first unlock.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { launcher.start() }
                }
            case .failure(let error):
                ContentUnavailableView("StrapLog could not start", systemImage: "exclamationmark.triangle",
                                       description: Text(String(describing: error)))
            }
        }
    }
}
