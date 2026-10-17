import AppIntents
import StrapLogCore
import UIKit

/// Builds the dependencies and starts recording work at process launch. Bluetooth state
/// restoration relaunches the app in the background with no SwiftUI scene, so the work
/// cannot hang off a view's `.task`; `didFinishLaunching` runs for every launch.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Created in `init` so the Polar central manager (with its restore identifier) exists
    /// before `didFinishLaunching` returns, as CoreBluetooth restoration requires.
    let dependencies: Result<AppDependencies, Error>
    private var launcher: Launcher?

    override init() {
        dependencies = Result { try AppDependencies() }
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if case .success(let deps) = dependencies {
            let launcher = Launcher(model: deps.model, source: deps.source)
            launcher.start()
            self.launcher = launcher
            // Shortcuts and Siri run their intents through the same launcher.
            AppDependencyManager.shared.add(dependency: launcher)
            StrapLogShortcuts.updateAppShortcutParameters()
        }
        return true
    }

    /// Best effort: a force-quit from the switcher of a suspended app never gets here, and the
    /// strap ends PMD streams when the link drops anyway; a later start clears a leftover stream.
    func applicationWillTerminate(_ application: UIApplication) {
        if case .success(let deps) = dependencies { deps.source.setMotionStreaming(false) }
    }
}
