import Foundation
import Testing
@testable import StrapLogCore

@Suite("RecordingSession")
struct RecordingSessionTests {
    @Test("notifications with 0/1/2/3 RRs → beat rows with idx and t_end_ms_est")
    func beatsPerNotification() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "rr")
        try await rig.play([
            .wait(ms: 1000), hr([]),
            .wait(ms: 1000), hr([1024]),
            .wait(ms: 1000), hr([800, 1024]),
            .wait(ms: 1000), hr([500, 600, 700]),
        ])
        let t0 = rig.clock.nowMs() - 4000
        let beats = try rig.beats()
        #expect(beats.map(\.rr1024) == [1024, 800, 1024, 500, 600, 700])
        #expect(beats.map(\.idx) == [0, 0, 1, 0, 1, 2])
        #expect(beats.map(\.rrMs) == [1000, 781.25, 1000, 488.28125, 585.9375, 683.59375])
        #expect(beats.map { $0.tEndMsEst - t0 } == [2000, 2000, 3000, 2730, 3316, 4000])
        #expect(try rig.count("notification") == 4)
        #expect(try DBInvariants.violations(rig.database.writer).isEmpty)
    }

    @Test("notification stores receipt time, HR, contact (incl. unknown)")
    func notificationFields() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "n")
        try await rig.play([.wait(ms: 5), hr([900], bpm: 72, contact: nil), hr([], bpm: 73, contact: false)])
        let rows = try rig.notifications()
        #expect(rows.map(\.hrBpm) == [72, 73])
        #expect(rows.map(\.contact) == [nil, false])
        #expect(rows.map(\.nRR) == [1, 0])
        #expect(rows[0].receivedAtMs == rig.clock.nowMs())
    }

    @Test("sensor data while idle is not recorded")
    func idleIgnored() async throws {
        let rig = try TestRig()
        try await rig.play([hr([1000]), .emit(.disconnected(reason: nil)), .emit(.bluetooth(poweredOn: false))])
        #expect(try rig.count("notification") == 0)
        #expect(try rig.count("event") == 0)
    }

    @Test("disconnect/reconnect → alternating, de-duplicated events with device and reason")
    func linkEvents() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "link")
        let id = try #require(await rig.session.recordingId)
        try await rig.play([
            .emit(.connected(deviceId: "H10-A", firmware: "5.0")),
            .wait(ms: 1000), hr([1000]),
            .wait(ms: 1000), .emit(.disconnected(reason: "out of range")),
            .emit(.disconnected(reason: "again")),
            .wait(ms: 60_000), .emit(.connected(deviceId: "H10-A", firmware: "5.0")),
            .emit(.connected(deviceId: "H10-A", firmware: "5.0")),
            .wait(ms: 1000), hr([1000]),
        ])
        try await rig.session.stop()
        let events = try rig.events(id)
        #expect(events.map(\.kind) == [.start, .connect, .disconnect, .connect, .stop])
        #expect(events[2].note == "out of range")
        #expect(events[3].atMs - events[2].atMs == 60_000)
        let rec = try #require(try rig.recording(id))
        #expect(rec.deviceId == "H10-A")
        #expect(rec.firmware == "5.0")
    }

    @Test("starting while already connected logs connect and battery at start")
    func connectedBeforeStart() async throws {
        let rig = try TestRig()
        try await rig.play([.emit(.connected(deviceId: "H10-B", firmware: nil)), .emit(.battery(percent: 90))])
        let id = try await rig.session.start(name: "pre")
        try await rig.play([.emit(.battery(percent: 88))])
        #expect(try rig.kinds(id) == [.start, .connect])
        let rec = try #require(try rig.recording(id))
        #expect(rec.deviceId == "H10-B")
        #expect(rec.batteryStart == 90)
        #expect(rec.batteryEnd == 88)
    }

    @Test("bluetooth power changes are logged")
    func bluetoothEvents() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "ble")
        try await rig.play([.emit(.bluetooth(poweredOn: false)), .wait(ms: 10), .emit(.bluetooth(poweredOn: true))])
        #expect(try rig.kinds(id) == [.start, .bleOff, .bleOn])
    }

    @Test("markers are events with their label")
    func markers() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "m")
        for label in ["a", "b", "c", "end", "felt dizzy"] {
            rig.clock.advance(byMs: 1000)
            try await rig.session.marker(label)
        }
        let markers = try rig.events(id).filter { $0.kind == .marker }
        #expect(markers.map(\.note) == ["a", "b", "c", "end", "felt dizzy"])
    }

    @Test("stop sets ended_at_ms, logs stop, and returns to idle")
    func stop() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "s")
        rig.clock.advance(byMs: 600_000)
        let rec = try await rig.session.stop()
        #expect(rec.endedAtMs == rig.clock.nowMs())
        #expect(rec.endedAtMs! - rec.startedAtMs == 600_000)
        #expect(try rig.recording(id)?.endedAtMs == rig.clock.nowMs())
        #expect(await rig.session.recordingId == nil)
        await #expect(throws: RecordingSessionError.notRecording) { try await rig.session.stop() }
        await #expect(throws: RecordingSessionError.notRecording) { try await rig.session.marker("a") }
    }

    @Test("start stores name, UTC start, and tz offset")
    func startFields() async throws {
        let rig = try TestRig(clock: FakeClock(startMs: 1_760_400_000_000, tzOffsetS: 9 * 3600))
        let id = try await rig.session.start(name: "Overnight")
        let rec = try #require(try rig.recording(id))
        #expect(rec.name == "Overnight")
        #expect(rec.startedAtMs == 1_760_400_000_000)
        #expect(rec.tzOffsetS == 9 * 3600)
        #expect(rec.endedAtMs == nil)
    }

    @Test("start refuses while recording or while an open recording exists")
    func startGuards() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "one")
        await #expect(throws: RecordingSessionError.alreadyRecording) { try await rig.session.start(name: "two") }
        let other = rig.relaunched()
        await #expect(throws: RecordingSessionError.openRecordingExists(id: id)) { try await other.start(name: "two") }
        #expect(try rig.count("recording") == 1)
    }

    @Test("consecutive recordings get separate ids and data")
    func twoRecordings() async throws {
        let rig = try TestRig()
        let a = try await rig.session.start(name: "a")
        try await rig.play([hr([1000])])
        try await rig.session.stop()
        let b = try await rig.session.start(name: "b")
        try await rig.play([hr([900, 950])])
        try await rig.session.stop()
        #expect(a != b)
        let byRec = Dictionary(grouping: try rig.beats(), by: \.recordingId).mapValues(\.count)
        #expect(byRec == [a: 1, b: 2])
        #expect(try DBInvariants.violations(rig.database.writer).isEmpty)
    }
}
