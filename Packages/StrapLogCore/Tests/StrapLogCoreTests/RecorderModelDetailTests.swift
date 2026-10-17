import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@MainActor
@Suite("RecorderModel: past recordings")
struct RecorderModelDetailTests {
    let database: StrapLogDatabase
    let clock = FakeClock()
    let dir: URL
    let model: RecorderModel

    init() throws {
        database = try .inMemory()
        dir = try scratchDirectory()
        model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
    }

    func record(_ name: String, beats: Int = 3) async {
        await model.start(name: name)
        await model.consume(FakeHeartSource(clock: clock, script: (0..<beats).flatMap { _ in [.wait(ms: 1000), hr([1024])] }))
        await model.marker(label: "a")
        await model.stop()
    }

    func index() throws -> ExportIndex {
        try JSONDecoder().decode(ExportIndex.self, from: Data(contentsOf: dir.appendingPathComponent(ExportIndex.fileName)))
    }

    /// Synchronous on purpose: in async contexts GRDB's `read` resolves to its async overload.
    func notes(in file: URL) throws -> String? {
        try DatabaseQueue(path: file.path).read { try String.fetchOne($0, sql: "SELECT notes FROM recording") }
    }

    @Test("Stop leaves the finished recording's summary for Home; the next Start clears it")
    func lastFinished() async throws {
        await record("seated")
        let finished = try #require(model.lastFinished)
        #expect(finished.recording.name == "seated")
        #expect(finished.summary.beats == 3)
        #expect(finished.summary.durationMs == 3000)
        #expect(finished.markers.map(\.label) == ["a"])
        await model.start(name: "next")
        #expect(model.lastFinished == nil)
    }

    @Test("detail loads summary, markers and the chart series; an unknown id is nil")
    func detail() async throws {
        await record("seated", beats: 5)
        let id = try #require(model.recordings.first?.id)
        let detail = try #require(await model.detail(id))
        #expect(detail.summary.beats == 5)
        #expect(detail.live.rrHistory.count == 5)
        #expect(detail.endMs == detail.recording.endedAtMs)
        #expect(await model.detail(999) == nil)
        #expect(model.errorMessage == nil)
    }

    @Test("an edit renames the snapshot file, re-exports it and refreshes the index")
    func edit() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        await record("old")
        let id = try #require(model.recordings.first?.id)
        let oldFile = try #require(model.lastSnapshot)

        let edited = try #require(await model.edit(id, RecordingEdit(name: "RAVINE", activity: "sleep", notes: "windy")))
        #expect(model.errorMessage == nil)
        #expect(edited.recording.name == "RAVINE" && edited.recording.activity == "sleep" && edited.recording.notes == "windy")
        #expect(model.recordings.map(\.name) == ["RAVINE"])
        #expect(model.lastFinished?.recording.name == "RAVINE")
        #expect(!FileManager.default.fileExists(atPath: oldFile.path))
        let newFile = try #require(await model.exportURL(for: edited.recording))
        #expect(newFile.lastPathComponent.hasSuffix("-RAVINE.sqlite"))
        #expect(try index().recordings.map(\.file) == [newFile.lastPathComponent])
        #expect(try index().recordings.map(\.activity) == ["sleep"])
        #expect(try notes(in: newFile) == "windy")
    }

    @Test("reexport restores a missing snapshot")
    func reexport() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        await record("gone")
        let detail = try #require(model.lastFinished)
        try FileManager.default.removeItem(at: try #require(model.lastSnapshot))
        #expect(await model.exportURL(for: detail.recording) == nil)
        await model.reexport(detail.id)
        #expect(await model.exportURL(for: detail.recording) != nil)
        #expect(try index().recordings.count == 1)
    }

    @Test("the recording being written cannot be edited or re-exported")
    func openRefused() async throws {
        await model.start(name: "live")
        let id = try #require(model.activeRecording?.id)
        #expect(await model.edit(id, RecordingEdit(name: "x", activity: "other")) == nil)
        #expect(model.errorMessage?.contains("cannotEditOpen") == true)
        #expect(model.activeRecording?.name == "live")
        model.dismissError()
        await model.reexport(id)
        #expect(model.errorMessage?.contains("cannotEditOpen") == true)
    }
}
