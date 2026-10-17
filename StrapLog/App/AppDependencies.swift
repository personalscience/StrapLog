import Foundation
import StrapLogCore

/// Composition root: picks the database location, the heart source and the export folder.
/// The source is built at once (CoreBluetooth restoration needs its central manager before
/// `didFinishLaunching` returns); the database only opens when `openModel` is called, which
/// can fail before first unlock after a reboot and is retried by `Launcher`.
@MainActor
struct AppDependencies {
    let source: any HeartSource
    let openModel: @MainActor () throws -> RecorderModel

    init(options: LaunchOptions = LaunchOptions()) throws {
        let dbURL: URL
        // Documents/StrapLog is what Files shows under On My iPhone → StrapLog.
        let local = URL.documentsDirectory.appending(path: "StrapLog")
        let exports: ExportFolder
        var defaults = UserDefaults.standard
        if options.freshDatabase {
            // Edited marker bars would otherwise leak between UI test runs.
            let suite = "StrapLog.fresh"
            UserDefaults.standard.removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
            dbURL = FileManager.default.temporaryDirectory.appending(path: "StrapLog-\(UUID().uuidString)/live.sqlite")
            exports = ExportFolder(local: local)
        } else {
            dbURL = URL.applicationSupportDirectory.appending(path: "StrapLog/live.sqlite")
            // The container's Documents is Files → iCloud Drive → StrapLog (NSUbiquitousContainers).
            exports = ExportFolder(local: local) {
                FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents")
            }
        }
        let info = Bundle.main.infoDictionary ?? [:]
        let appVersion = "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
        openModel = { [defaults] in
            RecorderModel(database: try .live(at: dbURL), exports: exports, appVersion: appVersion,
                          defaults: defaults, display: LiveActivityDisplay())
        }

        if let fixture = options.replayFixture {
            guard let url = Bundle.main.url(forResource: fixture, withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(fixture).json"])
            }
            source = try ReplayHeartSource.fixture(at: url, speed: options.replaySpeed)
        } else {
            source = PolarHeartSource()
        }
    }
}
