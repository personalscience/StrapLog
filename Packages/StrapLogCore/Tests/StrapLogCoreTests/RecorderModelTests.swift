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
        model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
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

    @Test("markers are written as marker events; blank notes are dropped")
    func markers() async throws {
        await model.start(name: "m")
        await model.marker(label: "a")
        await model.marker(note: "  free text ")
        await model.marker(note: "   ")
        await model.marker(label: "end")
        #expect(try strings("SELECT COALESCE(label, '-') || '|' || COALESCE(note, '-') FROM event WHERE kind = 'marker' ORDER BY id")
                == ["a|-", "-|free text", "end|-"])
    }

    @Test("the active recording's preset drives the marker bar; idle falls back to other")
    func activePreset() async throws {
        #expect(model.activePreset == .other)
        await model.start(.sleep, name: " ")
        #expect(model.activePreset == .sleep)
        #expect(model.activeRecording?.name.hasPrefix("sleep ") == true)
        await model.stop()
        #expect(model.recordings.map(\.activity) == ["sleep"])
        #expect(model.activePreset == .other)
    }

    @Test("each marker updates lastMarker and markerCount; relaunch restores them, Stop clears them")
    func markerFeedback() async throws {
        await model.start(name: "m")
        #expect(model.lastMarker == nil)
        await model.marker(label: "a")
        clock.advance(byMs: 2000)
        await model.marker(label: "b")
        #expect(model.lastMarker?.label == "b")
        #expect(model.lastMarker?.atMs == clock.nowMs())
        #expect(model.markerCount == 2)

        let relaunched = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
        await relaunched.launch()
        #expect(relaunched.lastMarker?.label == "b")
        #expect(relaunched.markers.map(\.label) == ["a", "b"])
        #expect(relaunched.markers == model.markers)

        await relaunched.stop()
        #expect(relaunched.lastMarker == nil)
        #expect(relaunched.markerCount == 0)
    }

    @Test("firmware and serial from DIS reach the model and the recording; firmware is written once")
    func deviceInformation() async throws {
        await play([.emit(.connected(deviceId: "H10-1", firmware: nil))])
        await model.start(name: "d")
        await play([.emit(.firmware("5.0.0")), .emit(.serialNumber("C1234567")), .emit(.firmware("6.0.0"))])
        #expect(model.firmware == "6.0.0")
        #expect(model.serialNumber == "C1234567")
        #expect(try strings("SELECT firmware FROM recording") == ["5.0.0"])

        await model.stop()
        await model.start(name: "e")
        #expect(try strings("SELECT firmware FROM recording ORDER BY id") == ["5.0.0", "6.0.0"],
                "a later recording opens with the latest DIS firmware")
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

        let relaunched = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
        await relaunched.launch()
        #expect(relaunched.activeRecording?.name == "overnight")
        #expect(relaunched.beatCount == 3)
        #expect(relaunched.lastHeardAtMs == clock.nowMs())
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "relaunch"])
    }

    @Test("motion streams only while recording: on for a resumed or started recording, off at Stop")
    func motionSwitch() async throws {
        let idle = HeartSourceSpy(FakeHeartSource(clock: clock, script: []))
        await model.consume(idle)
        #expect(idle.calls == [false])

        await model.start(name: "night")
        #expect(idle.calls == [false, true])
        await model.stop()
        #expect(idle.calls == [false, true, false])

        await model.start(name: "resumed")
        let relaunched = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
        await relaunched.launch()
        let source = HeartSourceSpy(FakeHeartSource(clock: clock, script: []))
        await relaunched.consume(source)
        #expect(source.calls == [true])
    }

    @Test("errors surface in errorMessage instead of throwing")
    func errorsSurface() async {
        await model.marker(label: "a")
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
        let model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, snapshotEveryMs: 10_000)
        await model.start(name: "night")
        await model.consume(FakeHeartSource(clock: clock, script: [.wait(ms: 6000), hr([1000]), .wait(ms: 6000), hr([1000])]))
        let url = try #require(model.lastSnapshot)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "snapshot"])
    }

    @Test("delete removes a finished recording's rows and its snapshot from every export folder")
    func deleteRecording() async throws {
        let cloud = try scratchDirectory()
        defer { for d in [dir, cloud] { try? FileManager.default.removeItem(at: d) } }
        let model = RecorderModel(database: database, exports: ExportFolder(local: dir) { cloud }, clock: clock)
        await model.start(name: "old")
        await model.consume(FakeHeartSource(clock: clock, script: [hr([1000, 1000])]))
        await model.marker(label: "a")
        await model.stop()
        let snapshot = try #require(model.lastSnapshot)
        let localCopy = dir.appendingPathComponent(snapshot.lastPathComponent)
        try FileManager.default.copyItem(at: snapshot, to: localCopy)
        clock.advance(byMs: 60_000)
        await model.start(name: "keep")
        await model.consume(FakeHeartSource(clock: clock, script: [hr([900])]))
        await model.stop()
        clock.advance(byMs: 60_000)
        await model.start(name: "newer")
        await model.stop()

        let old = try #require(model.recordings.first { $0.name == "old" })
        await model.delete(old)
        #expect(model.errorMessage == nil)
        #expect(model.recordings.map(\.name) == ["newer", "keep"])
        #expect(!FileManager.default.fileExists(atPath: snapshot.path))
        #expect(!FileManager.default.fileExists(atPath: localCopy.path))
        for table in ["notification", "beat", "event"] {
            #expect(try strings("SELECT COUNT(*) FROM \(table) WHERE recording_id = \(old.id)") == ["0"], "\(table)")
        }
        #expect(try strings("SELECT COUNT(*) FROM beat") == ["1"], "the other recording's beats remain")
        #expect(try index(in: cloud).recordings.map(\.name) == ["newer", "keep"])
        #expect(try index(in: dir).recordings.isEmpty)
    }

    private func index(in directory: URL) throws -> ExportIndex {
        try JSONDecoder().decode(ExportIndex.self, from: Data(contentsOf: directory.appendingPathComponent(ExportIndex.fileName)))
    }

    @Test("the recording being written cannot be deleted")
    func deleteActiveRefused() async throws {
        await model.start(name: "live")
        let live = try #require(model.recordings.first)
        await model.delete(live)
        #expect(model.errorMessage != nil)
        #expect(model.recordings.count == 1)
        #expect(model.isRecording)
    }

    @Test("an overnight recording takes a resting reading at the wake time, then stops itself and exports like a manual Stop")
    func autoStop() async throws {
        let wake = clock.nowMs() + 90_000
        await model.start(.sleep, name: "night", plan: OvernightPlan(wakeAtMs: wake))
        #expect(model.overnightPlan?.wakeAtMs == wake)
        await play([.wait(ms: 60_000), hr([1024])])
        #expect(model.markers.isEmpty)
        await play([.wait(ms: 30_000), hr([1024])])
        #expect(model.isRecording)
        #expect(model.lastMarker?.label == OvernightPlan.restingStartLabel)
        await play([.wait(ms: OvernightPlan.restingMs), hr([1024]), .wait(ms: 1000), hr([1024])])
        #expect(!model.isRecording)
        #expect(model.overnightPlan == nil)
        #expect(model.errorMessage == nil)
        #expect(try strings("SELECT note FROM event WHERE kind = 'stop'") == ["wake_time"])
        #expect(try strings("SELECT label FROM event WHERE kind = 'marker' ORDER BY id") == ["resting_start", "resting_end"])
        #expect(model.recordings.map(\.beatCount) == [3], "the event that tripped the stop is kept; later ones are not")
        let snapshot = try #require(model.lastSnapshot)
        #expect(FileManager.default.fileExists(atPath: snapshot.path))
    }
}
