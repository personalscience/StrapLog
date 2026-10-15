import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@MainActor
@Suite("RecorderModel")
struct RecorderModelTests {
    let database: StrapLogDatabase
    let clock = FakeClock()
    let dir: URL
    let model: RecorderModel

    init() throws {
        database = try .inMemory()
        dir = try scratchDirectory()
        model = RecorderModel(database: database, snapshotDirectory: dir, clock: clock)
    }

    /// Synchronous on purpose: in async contexts GRDB's `read` resolves to its async overload.
    func strings(_ sql: String, in reader: (any DatabaseReader)? = nil) throws -> [String] {
        try (reader ?? database.writer).read { try String.fetchAll($0, sql: sql) }
    }

    func play(_ script: [FakeHeartSource.Step]) async {
        await model.consume(FakeHeartSource(clock: clock, script: script))
    }

    @Test("idle → recording → idle, with link, battery and HR tracked throughout")
    func stateTransitions() async throws {
        await model.launch()
        #expect(model.link == .searching)
        #expect(!model.isRecording)

        await play([.emit(.connected(deviceId: "H10-1", firmware: nil)), .emit(.battery(percent: 88)), hr([1024], bpm: 61)])
        #expect(model.link == .connected(deviceId: "H10-1"))
        #expect(model.battery == 88)
        #expect(model.heartRate == 61)
        #expect(model.beatCount == 0, "beats before Start are not counted")

        await model.start(name: "  seated  ")
        #expect(model.activeRecording?.name == "seated")
        #expect(model.activeRecording?.batteryStart == 88)

        await play([.wait(ms: 1000), hr([800, 900]), .wait(ms: 4000), hr([1000]),
                    .emit(.disconnected(reason: nil))])
        #expect(model.beatCount == 3)
        #expect(model.longestGapMs == 4000)
        #expect(model.lastHeardAtMs == clock.nowMs())
        #expect(model.link == .disconnected)
        #expect(model.heartRate == nil)

        await model.stop()
        #expect(!model.isRecording)
        #expect(model.recordings.map(\.beatCount) == [3])
        #expect(model.recordings.first?.endedAtMs != nil)
        #expect(model.errorMessage == nil)
    }

    @Test("markers are written as marker events")
    func markers() async throws {
        await model.start(name: "m")
        for note in ["a", "b", "free text", "end"] { await model.marker(note) }
        #expect(try strings("SELECT note FROM event WHERE kind = 'marker' ORDER BY id") == ["a", "b", "free text", "end"])
    }

    @Test("each marker updates lastMarker and markerCount; relaunch restores them, Stop clears them")
    func markerFeedback() async throws {
        await model.start(name: "m")
        #expect(model.lastMarker == nil)
        await model.marker("a")
        clock.advance(byMs: 2000)
        await model.marker("b")
        #expect(model.lastMarker?.note == "b")
        #expect(model.lastMarker?.atMs == clock.nowMs())
        #expect(model.markerCount == 2)

        let relaunched = RecorderModel(database: database, snapshotDirectory: dir, clock: clock)
        await relaunched.launch()
        #expect(relaunched.lastMarker?.note == "b")
        #expect(relaunched.markerCount == 2)

        await relaunched.stop()
        #expect(relaunched.lastMarker == nil)
        #expect(relaunched.markerCount == 0)
    }

    @Test("Stop writes a snapshot file and remembers its URL")
    func stopSnapshots() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        await model.start(name: "snap")
        await play([hr([1024])])
        await model.stop()
        let url = try #require(model.lastSnapshot)
        #expect(url.deletingLastPathComponent().standardizedFileURL.path == dir.standardizedFileURL.path)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try strings("SELECT COUNT(*) FROM beat", in: DatabaseQueue(path: url.path)) == ["1"])
    }

    @Test("launch resumes an unfinished recording with its beat count")
    func launchResumes() async throws {
        await model.start(name: "overnight")
        await play([hr([1000, 1000]), .wait(ms: 1000), hr([1000])])

        let relaunched = RecorderModel(database: database, snapshotDirectory: dir, clock: clock)
        await relaunched.launch()
        #expect(relaunched.activeRecording?.name == "overnight")
        #expect(relaunched.beatCount == 3)
        #expect(relaunched.lastHeardAtMs == clock.nowMs())
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "relaunch"])
    }

    @Test("errors surface in errorMessage instead of throwing")
    func errorsSurface() async {
        await model.marker("a")
        #expect(model.errorMessage != nil)
        model.dismissError()
        #expect(model.errorMessage == nil)
    }

    @Test("Bluetooth off then on: bluetoothOff, then searching until reconnected")
    func bluetoothPower() async {
        await play([.emit(.connected(deviceId: "x", firmware: nil)), .emit(.bluetooth(poweredOn: false))])
        #expect(model.link == .bluetoothOff)
        await play([.emit(.bluetooth(poweredOn: true))])
        #expect(model.link == .searching)
    }

    @Test("going to the background while recording logs it and exports a snapshot; idle does neither")
    func backgroundSnapshot() async throws {
        await model.appPhase(.background)
        #expect(model.lastSnapshot == nil)
        await model.appPhase(.foreground)
        await model.start(name: "night")
        await model.appPhase(.background)
        let url = try #require(model.lastSnapshot)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "background", "snapshot"])
    }

    @Test("periodic snapshots during consume update lastSnapshot")
    func periodicSnapshot() async throws {
        let model = RecorderModel(database: database, snapshotDirectory: dir, clock: clock, snapshotEveryMs: 10_000)
        await model.start(name: "night")
        await model.consume(FakeHeartSource(clock: clock, script: [.wait(ms: 6000), hr([1000]), .wait(ms: 6000), hr([1000])]))
        let url = try #require(model.lastSnapshot)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "snapshot"])
    }
}
