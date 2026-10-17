import Foundation
import GRDB
import Testing
@testable import StrapLogCore

/// Start, Stop and Add Marker as Shortcuts and Siri run them: through `Launcher.whenLaunched`,
/// answering with a `CommandOutcome` instead of only setting `errorMessage`.
@MainActor
@Suite("Commands")
struct CommandTests {
    let database: StrapLogDatabase
    let clock = FakeClock()
    let dir: URL
    let model: RecorderModel

    init() throws {
        database = try .inMemory()
        dir = try scratchDirectory()
        model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
    }

    let wake = OvernightPlan(wakeAtMs: 1_760_621_400_000)

    @Test("start, a repeated start, marker label and note, stop, then idle answers")
    func lifecycle() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        await model.launch()
        #expect(await model.markIfRecording("awake") == .notRecording)
        #expect(await model.stopIfRecording() == .notRecording)

        guard case .done(let rec) = await model.startUnlessRecording(.sleep, plan: wake) else {
            Issue.record("start did not start"); return
        }
        #expect(rec.activity == "sleep")
        #expect(OvernightPlan(contextJSON: rec.context) == wake)
        #expect(await model.startUnlessRecording(.other, plan: wake) == .alreadyRecording(rec),
                "a second automation run leaves the night running")
        #expect(model.activeRecording?.id == rec.id)

        #expect(await model.markIfRecording("awake") == .done(rec))
        #expect(await model.markIfRecording("bathroom") == .done(rec))
        #expect(model.markers.map(\.label) == ["awake", nil])
        #expect(model.markers.map(\.note) == [nil, "bathroom"])
        if case .failed = await model.markIfRecording("  ") {} else { Issue.record("a blank marker is a failure") }

        #expect(await model.stopIfRecording() == .done(rec))
        #expect(!model.isRecording)
        #expect(try kinds(rec.id!) == ["start", "marker", "marker", "stop", "snapshot"])
    }

    @Test("RemoteCommand dispatch: start uses the saved wake time, then mark and stop")
    func remoteDispatch() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = try #require(UserDefaults(suiteName: "CommandTests.\(UUID())"))
        defaults.set(false, forKey: StartPreferences.stopAtWakeKey)
        let model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, defaults: defaults)
        let launcher = Launcher(model: model, source: FakeHeartSource(clock: clock, script: []))

        guard case .done(let rec) = try await launcher.run(.start(activity: "sleep", name: "nap")) else {
            Issue.record("start did not start"); return
        }
        #expect(rec.activity == "sleep")
        #expect(rec.name == "nap")
        #expect(OvernightPlan(contextJSON: rec.context) == OvernightPlan(wakeAtMs: nil), "stop-at-wake is off")
        #expect(try await launcher.run(.start(activity: "run")) == .alreadyRecording(rec))
        #expect(try await launcher.run(.mark("awake")) == .done(rec))
        #expect(model.markers.map(\.label) == ["awake"])
        #expect(try await launcher.run(.stop) == .done(rec))
        #expect(try await launcher.run(.stop) == .notRecording)
    }

    @Test("markNext steps through the bar the phone holds, and answers idle")
    func markNext() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        await model.launch()
        #expect(await model.run(.markNext) == .notRecording)
        guard case .done(let rec) = await model.startUnlessRecording(.other, plan: wake) else {
            Issue.record("start did not start"); return
        }
        for _ in 0..<5 { #expect(await model.run(.markNext) == .done(rec)) }
        #expect(model.markers.map(\.label) == ["a", "b", "c", "end", "end"])
    }

    @Test("a command waits for the launch resume, so it sees the open recording")
    func waitsForResume() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = try await RecordingSession(database: database, clock: clock).start(.sleep, name: "night", plan: wake)
        let launcher = Launcher(model: model, source: FakeHeartSource(clock: clock, script: []))
        let outcome = try await launcher.whenLaunched { await $0.startUnlessRecording(.sleep, plan: wake) }
        guard case .alreadyRecording(let rec) = outcome else { Issue.record("got \(outcome)"); return }
        #expect(rec.id == id)
    }

    /// Synchronous on purpose: in async contexts GRDB's `read` resolves to its async overload.
    func kinds(_ id: Int64) throws -> [String] {
        try database.writer.read { try String.fetchAll($0, sql: "SELECT kind FROM event WHERE recording_id = ? ORDER BY id",
                                                       arguments: [id]) }
    }
}
