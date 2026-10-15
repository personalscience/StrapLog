import Foundation
import Testing
@testable import StrapLogCore

@Suite("Resume after kill")
struct ResumeTests {
    @Test("kill and relaunch → same recording_id, relaunch event, no second start")
    func killAndResume() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "night")
        try await rig.play([.emit(.connected(deviceId: "H10", firmware: nil)), .wait(ms: 1000), hr([1000])])

        // Process dies; a new session on the same database is created at relaunch.
        rig.clock.advance(byMs: 30_000)
        let relaunched = rig.relaunched()
        #expect(try await relaunched.resumeIfOpen() == id)
        #expect(await relaunched.recordingId == id)

        try await FakeHeartSource(clock: rig.clock, script: [
            .emit(.connected(deviceId: "H10", firmware: nil)), .wait(ms: 1000), hr([1000]),
        ]).pump(into: relaunched)
        try await relaunched.stop()

        #expect(try rig.count("recording") == 1)
        #expect(try rig.kinds(id) == [.start, .connect, .relaunch, .connect, .stop])
        #expect(Set(try rig.beats().map(\.recordingId)) == [id])
        #expect(try DBInvariants.violations(rig.database.writer).isEmpty)
    }

    @Test("resume is idempotent within a process")
    func idempotent() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "x")
        let relaunched = rig.relaunched()
        #expect(try await relaunched.resumeIfOpen() == id)
        #expect(try await relaunched.resumeIfOpen() == id)
        #expect(try rig.kinds(id).filter { $0 == .relaunch }.count == 1)
    }

    @Test("nothing open → nil and no events")
    func nothingOpen() async throws {
        let rig = try TestRig()
        #expect(try await rig.session.resumeIfOpen() == nil)
        let id = try await rig.session.start(name: "x")
        try await rig.session.stop()
        #expect(try await rig.relaunched().resumeIfOpen() == nil)
        #expect(try rig.kinds(id) == [.start, .stop])
    }

    @Test("an unknown link after relaunch still logs the first disconnect")
    func disconnectAfterRelaunch() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "x")
        let relaunched = rig.relaunched()
        try await relaunched.resumeIfOpen()
        try await FakeHeartSource(clock: rig.clock, script: [.emit(.disconnected(reason: nil))]).pump(into: relaunched)
        #expect(try rig.kinds(id) == [.start, .relaunch, .disconnect])
    }
}
