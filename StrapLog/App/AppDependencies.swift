import Foundation
import StrapLogCore

/// Composition root: picks the database location, the heart source and the export folder.
@MainActor
struct AppDependencies {
    let model: RecorderModel
    let source: any HeartSource

    init(options: LaunchOptions = LaunchOptions()) throws {
        let fm = FileManager.default
        let dbURL: URL
        if options.freshDatabase {
            dbURL = fm.temporaryDirectory.appending(path: "StrapLog-\(UUID().uuidString)/live.sqlite")
        } else {
            dbURL = URL.applicationSupportDirectory.appending(path: "StrapLog/live.sqlite")
        }
        // Documents/StrapLog is what Files shows under On My iPhone → StrapLog.
        let exports = URL.documentsDirectory.appending(path: "StrapLog")
        model = RecorderModel(database: try .live(at: dbURL), snapshotDirectory: exports)

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
