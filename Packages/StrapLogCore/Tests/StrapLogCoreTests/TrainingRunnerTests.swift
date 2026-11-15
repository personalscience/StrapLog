import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@MainActor
@Suite("TrainingRunner")
struct TrainingRunnerTests {
    let database: StrapLogDatabase
    let clock = FakeClock()
    let model: RecorderModel
    let voice: VoiceSpy

    init() throws {
        database = try .inMemory()
        model = RecorderModel(database: database, exports: ExportFolder(local: try scratchDirectory()), clock: clock)
        voice = VoiceSpy(clock: clock)
    }

    func connect() async {
        await model.consume(FakeHeartSource(clock: clock, script: [.emit(.connected(deviceId: "band", firmware: nil))]))
    }

    func run(_ script: TrainingScript, sleeper: (any PacerSleeper)? = nil) async -> TrainingRunner {
        let runner = TrainingRunner(model: model, voice: voice, device: "armband", scripts: TrainingScript.all, clock: clock,
                                    sleeper: sleeper ?? HookSleeper(clock: clock))
        runner.start(script)
        #expect(runner.isRunning)
        await runner.finished()
        #expect(!runner.isRunning)
        return runner
    }

    func events() throws -> [RecordingEvent] {
        try read { try RecordingEvent.order(sql: "at_ms, id").fetchAll($0) }
    }

    /// Synchronous, so async tests get GRDB's blocking `read`.
    func read<T>(_ body: (Database) throws -> T) throws -> T { try database.writer.read(body) }

    func markers() throws -> [RecordingEvent] { try events().filter { $0.kind == .marker } }

    /// Each paced step's (marker, pacer_start, pacer_stop), in order.
    func pacedSpans(_ script: TrainingScript) throws -> [(step: TrainingStep, marker: Int64, t0: Int64, stop: Int64)] {
        let events = try events()
        let starts = events.filter { $0.kind == .pacerStart }
        let stops = events.filter { $0.kind == .pacerStop }
        let paced = script.steps.filter { $0.pacerRate != nil }
        #expect(starts.count == paced.count)
        #expect(stops.count == paced.count)
        let markers = try markers()
        return try zip(paced, zip(starts, stops)).map { step, pair in
            let marker = try #require(markers.first { $0.label == step.label })
            let t0 = try #require(pair.0.note.flatMap { PacerStamp(note: $0)?.t0Ms })
            return (step, marker.atMs, t0, pair.1.atMs)
        }
    }

    @Test("the calibration runs in order, timed from each step's real start, and saves its recording")
    func fullRun() async throws {
        await connect()
        let script = TrainingScript.calibration
        let start = clock.nowMs()
        let runner = await run(script)

        let markers = try markers()
        #expect(markers.map(\.label) == script.steps.map(\.label) + ["end"])
        #expect(markers.first?.note == "calibration v1")
        #expect(markers.first?.atMs == start)
        for (step, marker, t0, stop) in try pacedSpans(script) {
            #expect(t0 == marker + step.leadInMs, "\(step.label): chimes start after the lead-in")
            #expect(stop == t0 + step.durationMs - TrainingRunner.turnGuardMs, "\(step.label): ends on an out-breath")
        }
        // A hold begins where the pacer stopped, at the end of an out-breath.
        let stops = try events().filter { $0.kind == .pacerStop }.map(\.atMs)
        for hold in markers where hold.label?.hasPrefix("hold") == true { #expect(stops.contains(hold.atMs)) }
        let notes = try events().filter { $0.kind == .pacerStart }.compactMap(\.note)
        #expect(notes.allSatisfy { PacerStamp(note: $0).map { abs($0.inhaleS - $0.exhaleS) < 0.01 } == true }, "1:1 always")
        let paced = Int64(script.steps.filter { $0.pacerRate != nil }.count)
        #expect(clock.nowMs() - start == script.totalMs - paced * TrainingRunner.turnGuardMs, "on time, nothing drifts")

        let rec = try #require(try read { try Recording.fetchOne($0) })
        #expect(rec.name == script.recordingName)
        #expect(rec.activity == ActivityPreset.breathing.id)
        #expect(rec.endedAtMs != nil)
        #expect(model.lastFinished?.id == rec.id)
        #expect(model.pacer == nil)
        #expect(try DBInvariants.violations(database.writer).isEmpty)
        #expect(voice.begins == 1 && voice.ends == 1)
        #expect(voice.texts.last == "Done. Recording saved.")
        #expect(voice.texts.contains("After this breath out, hold."))
        #expect(voice.texts.filter { $0 == "Ten more." }.count == 2)
        #expect(runner.outcome == "Saved.")
    }

    @Test("the resonance finder steps 7 down to 4.5 /min, each run whole breaths, in a recording named for it")
    func resonance() async throws {
        await connect()
        let script = TrainingScript.resonance
        let runner = await run(script)
        #expect(try markers().map(\.label) == script.steps.map(\.label) + ["end"])
        let stamps = try events().filter { $0.kind == .pacerStart }.compactMap { $0.note.flatMap(PacerStamp.init(note:)) }
        #expect(stamps.map(\.breathsPerMinute) == [7, 6.5, 6, 5.5, 5, 4.5])
        for (step, _, t0, stop) in try pacedSpans(script) {
            #expect(stop == t0 + step.durationMs - TrainingRunner.turnGuardMs, "\(step.label)")
        }
        let rec = try #require(try read { try Recording.fetchOne($0) })
        #expect(rec.name == "resonance finder")
        #expect(runner.outcome == "Saved.")
        #expect(voice.texts.last == "Done. Recording saved.", "no beats, no ranking: the plain ending")
    }

    @Test("the resonance finder ends by saying the rate where heart rate swung most")
    func resonanceAnswer() async throws {
        await connect()
        let sleeper = BreathingSleeper(clock: clock, model: model) { 12 - 4 * abs($0 - 5.5) }
        let runner = await run(.resonance, sleeper: sleeper)
        #expect(runner.outcome == "Saved.")
        #expect(model.lastFinished?.resonance?.best.rate == 5.5)
        #expect(voice.texts.last == "Done. Largest swing at five and a half. Recording saved.")
    }

    @Test("a run whose recording ranks rates ends by saying the rate with the largest swing")
    func doneLine() throws {
        let ranking = try #require(ResonanceRanking(try ResonanceRankingTests.followed()))
        let line = TrainingRunner.doneLine(ranking)
        #expect(line == "Done. Largest swing at \(SpokenRate.words(ranking.best.rate)). Recording saved.")
        #expect(["Done. Largest swing at four and a half. Recording saved.",
                 "Done. Largest swing at six. Recording saved."].contains(line))
        #expect(TrainingRunner.doneLine(nil) == "Done. Recording saved.")
    }

    @Test("rates are said in words, whole and half")
    func spokenRates() {
        #expect(SpokenRate.words(5.5) == "five and a half")
        #expect(SpokenRate.words(7) == "seven")
        #expect(SpokenRate.words(4.5) == "four and a half")
        #expect(SpokenRate.words(10) == "ten")
        #expect(SpokenRate.words(5.25) == "5.25")
    }

    @Test("the run keeps raw accelerometer samples; an ordinary recording afterwards does not")
    func rawMotion() async throws {
        await connect()
        let still = (0..<51).map { AccSample(deviceNs: UInt64($0) * 19_600_000, x: 0, y: 0, z: 1000) }
        let runner = TrainingRunner(model: model, voice: voice, device: "armband", scripts: TrainingScript.all, clock: clock, sleeper: HookSleeper(clock: clock, hooks: [
            3: { [model, clock] in
                await model.consume(FakeHeartSource(clock: clock, script: [.emit(.motion(samples: still))]))
            },
        ]))
        runner.start(.rehearsal)
        await runner.finished()
        #expect(try read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM acc") } == 51)
    }

    // 900 ms overshoots the 200 ms turn guard, so some steps miss their turn and wait a breath.
    // Only early in the run: a fixed lateness period resonates with some rate's polls per breath
    // (7 at 4.5/min) and would miss every turn, which real ~20 ms jitter never does.
    @Test("a late wake delays what follows, skips nothing, and each paced step still ends on an out-breath")
    func lateWakes() async throws {
        await connect()
        let script = TrainingScript.calibration
        let start = clock.nowMs()
        _ = await run(script, sleeper: HookSleeper(clock: clock, lateMs: { $0 % 7 == 3 && $0 < 300 ? 900 : 0 }))

        #expect(try markers().map(\.label) == script.steps.map(\.label) + ["end"])
        for (step, marker, t0, stop) in try pacedSpans(script) {
            #expect(t0 >= marker + step.leadInMs, "\(step.label)")
            let period = 60_000 / step.pacerRate!
            let turn = stop + TrainingRunner.turnGuardMs
            let breaths = Double(turn - t0) / period
            #expect(stop < turn && stop >= turn - TrainingRunner.turnGuardMs, "\(step.label)")
            #expect(abs(breaths - breaths.rounded()) * period <= 1, "\(step.label): stops before an in-breath turn")
            #expect(Double(turn - t0) >= Double(step.durationMs) - 1, "\(step.label): never shortened")
        }
        #expect(clock.nowMs() - start > script.totalMs)
    }

    @Test("a mid-step line whose moment passed more than 3 s ago is dropped")
    func staleLine() async throws {
        await connect()
        let script = TrainingScript(name: "t", version: 1, recordingName: "t", rawMotion: false, steps: [
            .quiet("training", say: "Go.", seconds: 10, lines: [TrainingLine(afterMs: 5_000, text: "Halfway.")]),
        ])
        // Sleeps: 2 s, 2 s, then 1 s to the line, which overshoots by 4 s.
        _ = await run(script, sleeper: HookSleeper(clock: clock, lateMs: { $0 == 2 ? 4_000 : 0 }))
        #expect(!voice.texts.contains("Halfway."))
        #expect(try markers().map(\.label) == ["training", "end"])
    }

    @Test("start is refused, aloud, while a recording is open")
    func refusedWhileRecording() async throws {
        await connect()
        await model.start(name: "already")
        let runner = await run(.rehearsal)
        #expect(runner.outcome == "A recording is already open. Stop it first.")
        #expect(voice.texts == ["A recording is already open. Stop it first."])
        #expect(voice.begins == 1 && voice.ends == 1)
        #expect(try markers().isEmpty)
        #expect(try read { try Recording.fetchCount($0) } == 1)
    }

    @Test("start is refused, aloud, with the armband not connected")
    func refusedDisconnected() async throws {
        let runner = await run(.rehearsal)
        #expect(runner.outcome == "Armband not connected.")
        #expect(try read { try Recording.fetchCount($0) } == 0)
    }

    @Test("a lost armband mid-run is said at the next step; the run carries on")
    func disconnectMidRun() async throws {
        await connect()
        let runner = TrainingRunner(model: model, voice: voice, device: "armband", scripts: TrainingScript.all, clock: clock, sleeper: HookSleeper(clock: clock, hooks: [
            1: { [model, clock] in
                await model.consume(FakeHeartSource(clock: clock, script: [.emit(.disconnected(reason: nil))]))
            },
        ]))
        runner.start(.rehearsal)
        await runner.finished()
        #expect(voice.texts.contains("Armband not connected."))
        #expect(try markers().last?.label == "end")
    }

    @Test("Cancel stops the pacer, logs aborted, and saves the recording")
    func cancel() async throws {
        await connect()
        var runner: TrainingRunner?
        let sleeper = HookSleeper(clock: clock, hooks: [40: { @MainActor in runner?.cancel() }])
        runner = TrainingRunner(model: model, voice: voice, device: "armband", scripts: TrainingScript.all, clock: clock, sleeper: sleeper)
        runner?.start(.calibration)
        await runner?.finished()

        let markers = try markers()
        #expect(markers.last?.label == "aborted")
        #expect(markers.count < TrainingScript.calibration.steps.count)
        #expect(model.pacer == nil)
        #expect(!model.isRecording)
        #expect(model.lastFinished != nil)
        #expect(try events().filter { $0.kind == .pacerStart }.count == (try events().filter { $0.kind == .pacerStop }.count))
        #expect(voice.texts.last == "Training stopped.")
        #expect(voice.begins == 1 && voice.ends == 1)
        #expect(runner?.outcome == "Stopped early.")
        #expect(try DBInvariants.violations(database.writer).isEmpty)
    }

    @Test("a recording stopped from outside ends the run within a poll, pacer stopped, no second stop")
    func stoppedOutside() async throws {
        await connect()
        let sleeper = HookSleeper(clock: clock, hooks: [70: { [model] in await model.stop() }])
        let runner = await run(.calibration, sleeper: sleeper)
        _ = runner
        #expect(model.pacer == nil)
        #expect(try markers().last?.label != "aborted")
        #expect(try events().filter { $0.kind == .stop }.count == 1)
        #expect(voice.texts.last == "Training stopped.")
        #expect(voice.ends == 1)
        #expect(try DBInvariants.violations(database.writer).isEmpty)
    }

    @Test("the end turn is the planned end when on time, else the next in-breath turn after now")
    func endTurn() {
        let pacer = BreathingPacer(breathsPerMinute: 4.5, startedAtMs: 0)
        #expect(TrainingRunner.endTurnMs(pacer, notBeforeMs: 120_000, nowMs: 119_000) == 120_000)
        #expect(TrainingRunner.endTurnMs(pacer, notBeforeMs: 120_000, nowMs: 120_100) == 133_333)
        #expect(TrainingRunner.endTurnMs(pacer, notBeforeMs: 120_000, nowMs: 50_000) == 120_000)
    }

    @Test("the panel's step and time left follow the run")
    func panelState() async {
        await connect()
        final class Seen { var values: [(String?, Int?)] = [] }
        let seen = Seen()
        var runner: TrainingRunner?
        let sleeper = HookSleeper(clock: clock, hooks: [
            0: { @MainActor [clock] in seen.values.append((runner?.step?.label, runner?.secondsLeft(atMs: clock.nowMs()))) },
            1: { @MainActor [clock] in seen.values.append((runner?.step?.label, runner?.secondsLeft(atMs: clock.nowMs()))) },
        ])
        runner = TrainingRunner(model: model, voice: voice, device: "armband", scripts: TrainingScript.all, clock: clock, sleeper: sleeper)
        #expect(runner?.secondsLeft(atMs: 0) == nil)
        runner?.start(.rehearsal)
        await runner?.finished()
        #expect(seen.values.map(\.0) == ["training", "training"])
        #expect(seen.values.map(\.1) == [10, 8])
        #expect(runner?.step == nil && runner?.script == nil)
    }
}
