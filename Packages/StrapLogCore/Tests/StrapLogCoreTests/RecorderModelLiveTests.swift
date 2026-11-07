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
        let t0 = clock.nowMs()
        #expect(model.pacer == BreathingPacer(breathsPerMinute: 6, startedAtMs: t0))
        clock.advance(byMs: 60_000)
        await model.startPacer(breathsPerMinute: 5.5)
        #expect(model.pacer?.breathsPerMinute == 5.5)
        clock.advance(byMs: 60_000)
        await model.stopPacer()
        #expect(model.pacer == nil)
        await model.stopPacer()
        #expect(model.errorMessage == nil)
        #expect(try strings("SELECT kind || ':' || COALESCE(note, '') FROM event ORDER BY id")
                == ["start:", "pacer_start:6.0/min in5.0 out5.0 t0=\(t0)", "pacer_stop:",
                    "pacer_start:5.5/min in5.5 out5.5 t0=\(t0 + 60_000)", "pacer_stop:"])
    }

    @Test("the chosen ratio is stamped into pacer_start")
    func pacerRatioEvent() async throws {
        await model.start(name: "breathe")
        await model.startPacer(breathsPerMinute: 6, ratio: .fourSix)
        let t0 = clock.nowMs()
        #expect(model.pacer == BreathingPacer(breathsPerMinute: 6, ratio: .fourSix, startedAtMs: t0))
        #expect(try strings("SELECT note FROM event WHERE kind = 'pacer_start'") == ["6.0/min in4.0 out6.0 t0=\(t0)"])
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
        #expect(model.pacerScreenShown)
        await model.startPacer(breathsPerMinute: 6)
        await model.stopPacer()
        #expect(model.pacer == nil)
        #expect(model.errorMessage == nil)
        #expect(try strings("SELECT kind FROM event").isEmpty)
    }

    @Test("a recording started mid-breath logs pacer_start at its start, stamped with the pacer's true origin")
    func startWhilePacing() async throws {
        await model.startPacer(breathsPerMinute: 4.5)
        let pacer = model.pacer
        let t0 = clock.nowMs()
        clock.advance(byMs: 7_000)
        await model.start(name: "breathe")
        #expect(model.pacer == pacer, "the breath goes on uninterrupted")
        #expect(try strings("SELECT kind || ':' || COALESCE(note, '') FROM event ORDER BY id")
                == ["start:", "pacer_start:4.5/min in6.7 out6.7 t0=\(t0)"])
        #expect(t0 == clock.nowMs() - 7_000)
        #expect(try strings("SELECT at_ms FROM event ORDER BY id") == Array(repeating: String(clock.nowMs()), count: 2))
    }

    @Test("Record this session: a breathing recording starts under the running pacer without restarting it")
    func recordWhilePacing() async throws {
        await model.startPacer(breathsPerMinute: 6)
        let pacer = model.pacer
        let t0 = clock.nowMs()
        clock.advance(byMs: 7_000)
        await model.start(.breathing, name: "")
        #expect(try strings("SELECT activity FROM recording") == ["breathing"])
        #expect(try strings("SELECT kind || ':' || COALESCE(note, '') FROM event ORDER BY id")
                == ["start:", "pacer_start:6.0/min in5.0 out5.0 t0=\(t0)"])
        #expect(model.pacer == pacer)
    }

    /// A model whose pacer cues land in the returned spy.
    func cueingModel(limit: Int) throws -> (RecorderModel, CueSpy, SleeperSpy) {
        let cues = CueSpy(clock: clock)
        let sleeper = SleeperSpy(clock: clock, limit: limit)
        let model = RecorderModel(database: try .inMemory(), exports: ExportFolder(local: dir), clock: clock,
                                  cues: cues, sleeper: sleeper)
        return (model, cues, sleeper)
    }

    @Test("cues follow the pacer, and a recording's stop leaves them running")
    func cuesFollowThePacer() async throws {
        let (model, cues, sleeper) = try cueingModel(limit: 1)
        await model.start(name: "breathe")
        let t0 = clock.nowMs()
        await model.startPacer(breathsPerMinute: 6, ratio: .fourSix)
        await sleeper.waitUntilParked()
        #expect(cues.cues == [.init(atMs: t0, inhaling: true), .init(atMs: t0 + 4_000, inhaling: false)])
        await model.stop()
        #expect(cues.stops == 0, "finish() keeps the pacer, so its cues keep going")
        await model.stopPacer()
        #expect(cues.stops == 1)
    }

    @Test("changing rate restarts the cues from the new pacer")
    func rateChangeRestartsCues() async throws {
        let (model, cues, sleeper) = try cueingModel(limit: 0)
        await model.startPacer(breathsPerMinute: 6)
        await sleeper.waitUntilParked()
        clock.advance(byMs: 7_000)
        await model.startPacer(breathsPerMinute: 5)
        await sleeper.waitUntilParked()
        #expect(cues.stops == 1)
        #expect(cues.cues.map(\.atMs) == [clock.nowMs() - 7_000, clock.nowMs()])
        await model.stopPacer()
        #expect(cues.stops == 2)
    }

    @Test("stopping an idle pacer says nothing; stopping a running one tells the sink once")
    func stopCues() async throws {
        let (model, cues, sleeper) = try cueingModel(limit: 0)
        await model.stopPacer()
        #expect(cues.stops == 0)
        await model.startPacer(breathsPerMinute: 6)
        await sleeper.waitUntilParked()
        await model.stopPacer()
        #expect(cues.stops == 1)
    }

    @Test("leaving the pacer screen keeps the pacer and its cues running; Start shows the screen")
    func hideScreenKeepsPacer() async throws {
        model.showPacerScreen(true)
        #expect(model.pacerScreenShown && model.pacer == nil)
        await model.start(name: "breathe")
        await model.startPacer(breathsPerMinute: 6)
        model.showPacerScreen(false)
        #expect(!model.pacerScreenShown && model.pacer != nil)
        #expect(try strings("SELECT kind FROM event ORDER BY id") == ["start", "pacer_start"])
        await model.startPacer(breathsPerMinute: 5)
        #expect(model.pacerScreenShown)

        let (cueing, cues, sleeper) = try cueingModel(limit: 0)
        await cueing.startPacer(breathsPerMinute: 6)
        await sleeper.waitUntilParked()
        cueing.showPacerScreen(false)
        #expect(cues.stops == 0)
    }

    @Test("a saved pacer ratio falls back to the default")
    func savedRatio() {
        for ratio in BreathRatio.allCases { #expect(PacerSettings.ratio(ratio.rawValue) == ratio) }
        #expect(PacerSettings.ratio(nil) == .default)
        #expect(PacerSettings.ratio("fiveFive") == .default)
        #expect(PacerSettings.ratio("") == .default)
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
