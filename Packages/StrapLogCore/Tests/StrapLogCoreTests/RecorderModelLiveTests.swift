import Foundation
import GRDB
import HRVKit
import Testing
@testable import StrapLogCore

/// P5: live HRV and the breathing pacer as the view model exposes them.
@MainActor
@Suite("RecorderModel live metrics and pacer")
struct RecorderModelLiveTests {
    let database: StrapLogDatabase
    let clock = FakeClock()
    let dir: URL
    let model: RecorderModel

    init() throws {
        database = try .inMemory()
        dir = try scratchDirectory()
        model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
    }

    func strings(_ sql: String) throws -> [String] {
        try database.writer.read { try String.fetchAll($0, sql: sql) }
    }

    /// Stored beats of the only recording as the batch analyzer sees them (P7's loader does the same).
    func storedBeats() throws -> [TimedSample<Double>] {
        let rows = try database.writer.read { try Beat.order(sql: "id").fetchAll($0) }
        let origin = try #require(rows.first?.tEndMsEst)
        return rows.map { TimedSample(t: Double($0.tEndMsEst - origin) / 1000, value: $0.rrMs) }
    }

    @Test("windows from live notifications equal the batch over the stored beats, and survive a relaunch")
    func liveMatchesStored() async throws {
        let notifications = try ReplayHeartSource.fixture(at: RRFixture.url("resting")).notifications
        await model.start(name: "rest")
        await model.consume(FakeHeartSource(clock: clock, script: notifications.flatMap { [.wait(ms: 1000), hr($0)] }))

        let batch = model.live.analyzer.features(try storedBeats())
        #expect(model.live.windows.count >= 10)   // 20 s stride over ≈ 15 min of fixture
        #expect(Array(batch.prefix(model.live.windows.count)) == model.live.windows)
        #expect(model.live.latest == model.live.windows.last)
        #expect(!model.live.rrHistory.isEmpty)

        let relaunched = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock)
        await relaunched.launch()
        #expect(relaunched.live.windows == model.live.windows)
        #expect(relaunched.live.rrHistory == model.live.rrHistory)
    }

    @Test("notifications without beats for 10 s set the beat gap; a beat clears it")
    func beatGap() async {
        await model.start(name: "gap")
        let empty: [FakeHeartSource.Step] = Array(repeating: [.wait(ms: 1000), hr([])], count: 10).flatMap { $0 }
        await model.consume(FakeHeartSource(clock: clock, script: [.emit(.connected(deviceId: "H10", firmware: nil)), hr([1024])] + empty.dropLast(2)))
        #expect(model.liveStatus?.beatGap == false, "9 s without beats is not a gap yet")
        await model.consume(FakeHeartSource(clock: clock, script: [.wait(ms: 1000), hr([])]))
        #expect(model.liveStatus?.beatGap == true)
        #expect(model.liveStatus?.linkText == "No beats")
        await model.consume(FakeHeartSource(clock: clock, script: [.wait(ms: 1000), hr([1024])]))
        #expect(model.liveStatus?.beatGap == false)
    }

    @Test("Start and Stop reset the live metrics")
    func resets() async {
        await model.start(name: "a")
        await model.consume(FakeHeartSource(clock: clock, script: [hr([1024, 1024])]))
        #expect(model.live.rrHistory.count == 2)
        await model.stop()
        #expect(model.live.rrHistory.isEmpty)
        await model.start(name: "b")
        #expect(model.live.rrHistory.isEmpty)
    }

    @Test("pacer start and stop are logged with the rate; changing rate restarts it")
    func pacerEvents() async throws {
        await model.start(name: "breathe")
        await model.startPacer(breathsPerMinute: 6)
        #expect(model.pacer == BreathingPacer(breathsPerMinute: 6, startedAtMs: clock.nowMs()))
        clock.advance(byMs: 60_000)
        await model.startPacer(breathsPerMinute: 5.5)
        #expect(model.pacer?.breathsPerMinute == 5.5)
        clock.advance(byMs: 60_000)
        await model.stopPacer()
        #expect(model.pacer == nil)
        await model.stopPacer()
        #expect(model.errorMessage == nil)
        #expect(try strings("SELECT kind || ':' || COALESCE(note, '') FROM event ORDER BY id")
                == ["start:", "pacer_start:6.0/min", "pacer_stop:", "pacer_start:5.5/min", "pacer_stop:"])
    }

    @Test("Stop with the pacer running logs pacer_stop before stop and leaves the pacer running")
    func stopKeepsPacer() async throws {
        await model.start(name: "breathe")
        await model.startPacer(breathsPerMinute: BreathingPacer.defaultRate)
        let pacer = model.pacer
        await model.stop()
        #expect(model.pacer == pacer)
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "pacer_start", "pacer_stop", "stop", "snapshot"])
        await model.stopPacer()
        #expect(model.errorMessage == nil, "stopping it after the recording writes nothing")
        #expect(try strings("SELECT kind FROM event WHERE kind LIKE 'pacer%'") == ["pacer_start", "pacer_stop"])
    }

    @Test("the pacer runs without a recording and writes nothing")
    func pacerWhileIdle() async throws {
        await model.startPacer(breathsPerMinute: 5)
        #expect(model.pacer == BreathingPacer(breathsPerMinute: 5, startedAtMs: clock.nowMs()))
        #expect(model.pacerPanelShown)
        await model.startPacer(breathsPerMinute: 6)
        await model.stopPacer()
        #expect(model.pacer == nil)
        #expect(model.errorMessage == nil)
        #expect(try strings("SELECT kind FROM event").isEmpty)
    }

    @Test("a recording started mid-breath logs pacer_start at its start, keeping the pacer's phase")
    func startWhilePacing() async throws {
        await model.startPacer(breathsPerMinute: 4.5)
        let pacer = model.pacer
        clock.advance(byMs: 7_000)
        await model.start(name: "breathe")
        #expect(model.pacer == pacer, "the breath goes on uninterrupted")
        #expect(try strings("SELECT kind || ':' || COALESCE(note, '') FROM event ORDER BY id")
                == ["start:", "pacer_start:4.5/min"])
        #expect(try strings("SELECT at_ms FROM event ORDER BY id") == Array(repeating: String(clock.nowMs()), count: 2))
    }

    @Test("hiding the pacer panel stops the pacer")
    func hidePanel() async throws {
        await model.showPacerPanel(true)
        #expect(model.pacerPanelShown && model.pacer == nil)
        await model.start(name: "breathe")
        await model.startPacer(breathsPerMinute: 6)
        await model.showPacerPanel(false)
        #expect(!model.pacerPanelShown && model.pacer == nil)
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "pacer_start", "pacer_stop"])
    }

    @Test("a saved pacer rate is snapped into range")
    func savedRate() {
        #expect(PacerSettings.rate(6) == 6)
        #expect(PacerSettings.rate(5.4) == 5.5)
        #expect(PacerSettings.rate(2) == BreathingPacer.rates.lowerBound)
        #expect(PacerSettings.rate(12) == BreathingPacer.rates.upperBound)
        #expect(PacerSettings.rate(.nan) == BreathingPacer.defaultRate)
    }
}
