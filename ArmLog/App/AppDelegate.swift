import AppIntents
import StrapLogCore
import UIKit

/// Builds the dependencies and starts recording work at process launch. Bluetooth state
/// restoration relaunches the app in the background with no SwiftUI scene, so the work
/// cannot hang off a view's `.task`; `didFinishLaunching` runs for every launch.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Created in `init` so the central manager (with its restore identifier) exists before
    /// `didFinishLaunching` returns. Fails only for a bad `-replay` fixture.
    let launcher: Result<Launcher, Error>
    private let source: (any HeartSource)?
    /// Training mode's runner, once the database is open.
    let training: TrainingSlot?

    override init() {
        let dependencies = Result { try AppDependencies(options: LaunchOptions()) }
        launcher = dependencies.map { Launcher(source: $0.source, openModel: $0.openModel) }
        source = try? dependencies.get().source
        training = try? dependencies.get().training
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if case .success(let launcher) = launcher {
            launcher.start()
            // The Live Activity's Stop and marker buttons run through the same launcher.
            AppDependencyManager.shared.add(dependency: launcher)
        }
        return true
    }

    /// First unlock after a reboot: a restoration launch before it could not open the database.
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        if case .success(let launcher) = launcher { launcher.start() }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        source?.setMotionStreaming(false)
    }
}
