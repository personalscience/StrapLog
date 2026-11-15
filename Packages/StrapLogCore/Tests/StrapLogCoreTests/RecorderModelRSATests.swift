import Foundation
import GRDB
import Testing
@testable import StrapLogCore

/// straplog-9fr.4: the RSA reading as the view model exposes it.
@MainActor
@Suite("RecorderModel RSA")
struct RecorderModelRSATests {
    let database: StrapLogDatabase
    let clock = FakeClock()
    let dir: URL
    let defaults: UserDefaults
    let model: RecorderModel

    init() throws {
        database = try .inMemory()
        dir = try scratchDirectory()
        defaults = try #require(UserDefaults(suiteName: "rsa-\(UUID())"))
        model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, defaults: defaults)
    }

    /// `seconds` of beats at a steady 60 bpm, one per notification.
    func beats(_ seconds: Int) -> [FakeHeartSource.Step] {
        Array(repeating: [.wait(ms: 1000), hr([1024])], count: seconds).flatMap { $0 }
    }

    func play(_ script: [FakeHeartSource.Step], capabilities: SensorCapabilities = SensorCapabilities()) async {
        await model.consume(HeartSourceSpy(FakeHeartSource(clock: clock, script: script), capabilities: capabilities))
    }

    func count(_ table: String) throws -> Int {
        try database.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 }
    }

    @Test("a reading only with the pacer running, its screen shown, RSA on and the app in front; none written idle")
    func conditions() async throws {
        await play(beats(3))
        #expect(model.rsa == nil, "off by default")
        model.setRSA(true)
        await play(beats(3))
        #expect(model.rsa == nil, "no pacer")

        await model.startPacer(breathsPerMinute: 6)
        await play(beats(30))
        let reading = try #require(model.rsa, "works with no recording open")
        #expect(reading.trace.count == 30)
        #expect(!reading.warmingUp, "two 10 s breaths have closed")
        #expect(try count("beat") == 0)

        model.showPacerScreen(false)
        #expect(model.rsa == nil)
        await play(beats(3))
        #expect(model.rsa == nil)
        model.showPacerScreen(true)
        await play(beats(2))
        #expect(model.rsa?.trace.count == 2, "a fresh tracker once shown again")

        await model.appPhase(.background)
        #expect(model.rsa == nil)
        await play(beats(3))
        #expect(model.rsa == nil)
        await model.appPhase(.foreground)

        model.setRSA(false)
        #expect(model.rsa == nil)
        await play(beats(3))
        #expect(model.rsa == nil)
        model.setRSA(true)
        await model.stopPacer()
        await play(beats(3))
        #expect(model.rsa == nil)

        let relaunched = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, defaults: defaults)
        #expect(relaunched.rsaOn, "remembered")
    }

    @Test("a pacer rate change starts a new tracker")
    func rateChange() async throws {
        model.setRSA(true)
        await model.startPacer(breathsPerMinute: 6)
        await play(beats(30))
        #expect(model.rsa?.breaths.isEmpty == false)
        await model.startPacer(breathsPerMinute: 8)
        #expect(model.rsa == nil)
        await play(beats(2))
        let r = try #require(model.rsa)
        #expect(r.trace.count == 2 && r.breaths.isEmpty && r.warmingUp)
    }

    @Test("a disconnect clears the reading; the next beats start afresh")
    func disconnect() async throws {
        model.setRSA(true)
        await model.startPacer(breathsPerMinute: 6)
        await play(beats(30) + [.emit(.disconnected(reason: nil))])
        #expect(model.rsa == nil)
        await play(beats(2))
        #expect(model.rsa?.trace.count == 2)
        #expect(model.rsa?.breaths.isEmpty == true)
    }

    @Test("the reading is the same while recording, and recording is unchanged by it")
    func whileRecording() async throws {
        model.setRSA(true)
        await model.start(name: "paced")
        await model.startPacer(breathsPerMinute: 6)
        await play(beats(30))
        #expect(model.rsa?.trace.count == 30)
        #expect(model.beatCount == 30)
        #expect(try count("beat") == 30)
    }

    @Test("a sensor without beat-accurate RR never reads, even with RSA remembered on")
    func noBeatToBeat() async throws {
        defaults.set(true, forKey: PacerSettings.rsaKey)
        let model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, defaults: defaults)
        let armband = SensorCapabilities(ecg: false, placement: .arm, optical: true, beatToBeat: false)
        await model.startPacer(breathsPerMinute: 6)
        await model.consume(HeartSourceSpy(FakeHeartSource(clock: clock, script: beats(30)), capabilities: armband))
        #expect(model.rsaOn)
        #expect(!model.rsaShown)
        #expect(model.rsa == nil)
    }
}
