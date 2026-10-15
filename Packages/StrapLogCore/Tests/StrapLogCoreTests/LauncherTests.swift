import Foundation
import GRDB
import Testing
@testable import StrapLogCore

/// The restoration path: iOS relaunches the app in the background for a Bluetooth event,
/// `didFinishLaunching` calls `Launcher.start()`, and data must land in the open recording.
@MainActor
@Suite("Launcher")
struct LauncherTests {
    @Test("a background relaunch resumes the open recording and ingests into it")
    func restorationResumes() async throws {
        let database = try StrapLogDatabase.inMemory()
        let clock = FakeClock()
        let id = try await RecordingSession(database: database, clock: clock).start(name: "night")
        clock.advance(byMs: 45_000)

        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = RecorderModel(database: database, snapshotDirectory: dir, clock: clock)
        let source = FakeHeartSource(clock: clock, script: [
            .emit(.connected(deviceId: "H10", firmware: nil)), .wait(ms: 1000),
            .emit(.heartRate(bpm: 60, contact: true, rr1024: [1024, 1000])),
        ])
        let launcher = Launcher(model: model, source: source)
        let task = launcher.start()
        #expect(launcher.start() == task, "a second call does not start a second consumer")
        await task.value

        #expect(model.activeRecording?.id == id)
        #expect(model.beatCount == 2)
        #expect(try strings("SELECT kind FROM event WHERE recording_id = \(id) ORDER BY id", database)
                == ["start", "relaunch", "connect"])
        #expect(try strings("SELECT DISTINCT recording_id FROM beat", database) == ["\(id)"])
    }

    /// Synchronous on purpose: in async contexts GRDB's `read` resolves to its async overload.
    func strings(_ sql: String, _ database: StrapLogDatabase) throws -> [String] {
        try database.writer.read { try String.fetchAll($0, sql: sql) }
    }
}
