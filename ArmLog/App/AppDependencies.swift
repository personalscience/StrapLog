import Foundation
import StrapLogCore

/// Composition root: the database location, the armband source and the export folder.
/// The source is built at once (CoreBluetooth restoration needs its central manager before
/// `didFinishLaunching` returns); the database opens when `openModel` is called, which can
/// fail before first unlock after a reboot and is retried by `Launcher`.
/// No Watch in v1; the Live Activity is StrapLog's (`LiveActivityDisplay`). Exports stay on the phone (Files → On My iPhone →
/// ArmLog), with no iCloud container yet.
@MainActor
struct AppDependencies {
    let source: any HeartSource
    let openModel: @MainActor () throws -> RecorderModel
    /// Training mode's runner, filled in by `openModel`.
    let training = TrainingSlot()

    init(options: LaunchOptions = LaunchOptions()) throws {
        let app = AppBrand.current.appName
        let exports = ExportFolder(local: URL.documentsDirectory.appending(path: app))
        let dbURL: URL
        var defaults = UserDefaults.standard
        if options.freshDatabase {
            let suite = "\(app).fresh"
            UserDefaults.standard.removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
            dbURL = FileManager.default.temporaryDirectory.appending(path: "\(app)-\(UUID().uuidString)/live.sqlite")
        } else {
            dbURL = URL.applicationSupportDirectory.appending(path: "\(app)/live.sqlite")
        }
        let info = Bundle.main.infoDictionary ?? [:]
        let appVersion = "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
        openModel = { [defaults, training] in
            // One rig for the chimes and the training voice, so a run keeps one engine alive.
            let rig = AudioRig()
            let sounds = PacerSounds(rig: rig)
            let model = RecorderModel(database: try .live(at: dbURL), exports: exports, appVersion: appVersion,
                                      defaults: defaults, display: LiveActivityDisplay(), cues: sounds)
            training.runner = TrainingRunner(model: model, voice: SpokenTraining(rig: rig, sounds: sounds),
                                             device: AppBrand.current.device,
                                             scripts: [.calibration, .rehearsal])
            return model
        }

        if let fixture = options.replayFixture {
            guard let url = Bundle.main.url(forResource: fixture, withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(fixture).json"])
            }
            source = try ReplayHeartSource.fixture(at: url, speed: options.replaySpeed)
        } else {
            source = ArmbandHeartSource()
        }
    }
}
