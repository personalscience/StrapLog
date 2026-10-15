import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("Background resilience")
struct BackgroundTests {
    func coverage(_ rig: TestRig, _ id: Int64) throws -> Coverage {
        try rig.database.writer.read { try Coverage.of(recording: id, db: $0) }
    }

    @Test("Bluetooth toggled off and on mid-recording → bracketed gap, data resumes in the same recording")
    func bluetoothToggle() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "night")
        try await rig.play([
            .emit(.connected(deviceId: "H10", firmware: nil)), .wait(ms: 1000), hr([1000]), .wait(ms: 1000), hr([1000]),
            .wait(ms: 500), .emit(.bluetooth(poweredOn: false)), .emit(.disconnected(reason: "poweredOff")),
            .wait(ms: 60_000), .emit(.bluetooth(poweredOn: true)), .wait(ms: 2000),
            .emit(.connected(deviceId: "H10", firmware: nil)), .wait(ms: 1000), hr([1000]), .wait(ms: 1000), hr([1000]),
        ])
        #expect(try rig.kinds(id) == [.start, .connect, .bleOff, .disconnect, .bleOn, .connect])

        let c = try coverage(rig, id)
        #expect(c.gaps.count == 1)
        #expect(c.gaps[0].durationMs == 63_500)
        #expect(c.gaps[0].isBracketed)
        #expect(c.unbracketedGaps.isEmpty)
        #expect(try DBInvariants.violations(rig.database.writer).isEmpty)
    }

    @Test("snapshotIfDue fires every 30 min of recording time, driven by HR notifications")
    func snapshotCadence() async throws {
        let rig = try TestRig()
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let every: Int64 = 30 * 60_000
        let id = try await rig.session.start(name: "night")

        var fired: [Int64] = []
        for minute in 1...95 {
            rig.clock.advance(byMs: 60_000)
            try await rig.session.ingest(SensorEvent(atMs: rig.clock.nowMs(), .heartRate(bpm: 60, contact: true, rr1024: [1024])))
            if try await rig.session.snapshotIfDue(into: dir, everyMs: every) != nil { fired.append(Int64(minute)) }
        }
        #expect(fired == [30, 60, 90])
        #expect(try rig.kinds(id).filter { $0 == .snapshot }.count == 3)
        let rec = try #require(try rig.recording(id))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(Snapshot.fileName(for: rec)).path))
    }

    @Test("snapshotIfDue is a no-op while idle")
    func snapshotIdle() async throws {
        let rig = try TestRig()
        rig.clock.advance(byMs: 3_600_000)
        #expect(try await rig.session.snapshotIfDue(into: scratchDirectory(), everyMs: 1) == nil)
    }

    @Test("after a relaunch the cadence continues from the last snapshot, not from the relaunch")
    func cadenceAcrossRelaunch() async throws {
        let rig = try TestRig()
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let every: Int64 = 30 * 60_000
        try await rig.session.start(name: "night")
        rig.clock.advance(byMs: every)
        #expect(try await rig.session.snapshotIfDue(into: dir, everyMs: every) != nil)

        rig.clock.advance(byMs: 10 * 60_000)
        let relaunched = rig.relaunched()
        try await relaunched.resumeIfOpen()
        rig.clock.advance(byMs: 15 * 60_000)
        #expect(try await relaunched.snapshotIfDue(into: dir, everyMs: every) == nil)
        rig.clock.advance(byMs: 5 * 60_000)
        #expect(try await relaunched.snapshotIfDue(into: dir, everyMs: every) != nil)
    }

    @Test("low strap battery logs one low_battery event per recording, never while idle")
    func lowBattery() async throws {
        let rig = try TestRig()
        try await rig.play([.emit(.battery(percent: 5))])
        let id = try await rig.session.start(name: "night")
        try await rig.play([.emit(.battery(percent: 40)), .wait(ms: 1000), .emit(.battery(percent: 10)),
                            .wait(ms: 1000), .emit(.battery(percent: 5))])
        let low = try rig.events(id).filter { $0.kind == .lowBattery }
        #expect(low.map(\.note) == ["10%"])
        #expect(try rig.recording(id)?.batteryEnd == 5)
    }

    @Test("app phase changes are logged only while recording and only when they change")
    func appPhase() async throws {
        let rig = try TestRig()
        try await rig.session.appPhase(.foreground)
        let id = try await rig.session.start(name: "night")
        try await rig.session.appPhase(.foreground)
        try await rig.session.appPhase(.background)
        try await rig.session.appPhase(.background)
        try await rig.session.appPhase(.foreground)
        #expect(try rig.kinds(id) == [.start, .background, .foreground])
    }
}
