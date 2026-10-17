import AppIntents
import StrapLogCore
import UIKit

/// Builds the dependencies and starts recording work at process launch. Bluetooth state
/// restoration relaunches the app in the background with no SwiftUI scene, so the work
/// cannot hang off a view's `.task`; `didFinishLaunching` runs for every launch.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Created in `init` so the Polar central manager (with its restore identifier) exists
    /// before `didFinishLaunching` returns, as CoreBluetooth restoration requires. Fails only
    /// for a bad `-replay` fixture; a database that cannot open yet is the launcher's to retry.
    let launcher: Result<Launcher, Error>
    private let source: (any HeartSource)?

    override init() {
        let dependencies = Result { try AppDependencies() }
        launcher = dependencies.map { Launcher(source: $0.source, openModel: $0.openModel) }
        source = try? dependencies.get().source
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if case .success(let launcher) = launcher {
            launcher.start()
            // Shortcuts and Siri run their intents through the same launcher.
            AppDependencyManager.shared.add(dependency: launcher)
            StrapLogShortcuts.updateAppShortcutParameters()
        }
        return true
    }

    /// First unlock after a reboot: a restoration launch before it could not open the database.
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        if case .success(let launcher) = launcher { launcher.start() }
    }

    /// Best effort: a force-quit from the switcher of a suspended app never gets here, and the
    /// strap ends PMD streams when the link drops anyway; a later start clears a leftover stream.
    func applicationWillTerminate(_ application: UIApplication) {
        source?.setMotionStreaming(false)
    }
}
