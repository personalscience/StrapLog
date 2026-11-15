import Observation

/// Runs a `TrainingScript` hands-free: for each step it speaks the line (`TrainingVoice`), logs
/// the step's marker, and starts or stops the pacer, all through `RecorderModel`, so the
/// recording's events carry the truth for every second.
///
/// A sleeping task like `PacerClock`, for the same reason: a silent step or a hold has no BLE
/// notification to ride on (ArmLog's third exception, with `PacerClock` and the armband watchdog).
///
/// - Owns its recording: refuses to start while one is open or the sensor is not connected,
///   starts a `breathing` recording named by the script (keeping raw accelerometer samples if the
///   script asks), and stops and saves it.
/// - Relative timing, never skip: each step runs its full length from when it really started; a
///   late wake makes what follows late. A paced step ends at the first in-breath turn at or after
///   its planned end (stopping `turnGuardMs` before it, so no inhale chime sounds), so a late step
///   still ends on an out-breath. A mid-step line more than `staleLineMs` late is dropped.
/// - Aborts on `cancel`, or when its recording is no longer open (stopped from the Recording
///   screen, an intent, or auto-stop): stops the pacer, logs `aborted` if it still can, saves.
@MainActor
@Observable
public final class TrainingRunner {
    /// The script being run, or nil when idle.
    public private(set) var script: TrainingScript?
    /// The step in progress.
    public private(set) var step: TrainingStep?
    /// When the step in progress is planned to end.
    public private(set) var stepEndsAtMs: Int64?
    /// What the last run ended with, for the panel: nil while running or before any run.
    public private(set) var outcome: String?

    public var isRunning: Bool { script != nil }

    /// The scripts this app offers, in menu order.
    public let scripts: [TrainingScript]

    private let model: RecorderModel
    /// Said when the sensor is not connected, e.g. `Armband not connected.`
    private let notConnected: String
    private let voice: any TrainingVoice
    private let clock: any WallClock
    private let sleeper: any PacerSleeper
    private var task: Task<Void, Never>?

    /// The longest single sleep, so a recording stopped elsewhere is noticed within it.
    public static let pollMs: Int64 = 2_000
    /// How long before an in-breath turn a paced step stops its pacer.
    public static let turnGuardMs: Int64 = 200
    /// A mid-step line later than this is dropped rather than said out of place.
    public static let staleLineMs: Int64 = 3_000

    /// `device` is the sensor's noun, lower case (`armband`, `strap`), for what the voice says.
    public init(model: RecorderModel, voice: any TrainingVoice, device: String, scripts: [TrainingScript],
                clock: any WallClock = SystemClock(), sleeper: any PacerSleeper = TaskSleeper()) {
        self.model = model
        self.scripts = scripts
        notConnected = device.prefix(1).uppercased() + device.dropFirst() + " not connected."
        self.voice = voice
        self.clock = clock
        self.sleeper = sleeper
    }

    /// Starts `script` unless a run is in progress.
    public func start(_ script: TrainingScript) {
        guard task == nil else { return }
        self.script = script
        outcome = nil
        task = Task { await run(script) }
    }

    /// Stops the run early; it cleans up and saves its recording.
    public func cancel() {
        task?.cancel()
    }

    /// Returns when the run in progress (if any) has finished.
    public func finished() async {
        await task?.value
    }

    /// Whole seconds left in the step in progress, at `atMs`.
    public func secondsLeft(atMs: Int64) -> Int? {
        stepEndsAtMs.map { Int((max(0, $0 - atMs) + 999) / 1000) }
    }

    // MARK: Run

    private struct Stopped: Error {}

    private func run(_ script: TrainingScript) async {
        voice.begin()
        defer {
            voice.end()
            self.script = nil
            step = nil
            stepEndsAtMs = nil
            task = nil
        }
        if model.isRecording { return refuse("A recording is already open. Stop it first.") }
        if !model.link.isConnected { return refuse(notConnected) }
        await model.start(.breathing, name: script.recordingName, rawMotion: script.rawMotion)
        guard let id = model.activeRecording?.id else { return refuse("Could not start the recording.") }
        do {
            for (i, step) in script.steps.enumerated() {
                try await perform(step, note: i == 0 ? script.stamp : nil, recordingId: id)
            }
            await model.stopPacer()
            await model.marker(label: TrainingScript.endLabel)
            await model.stop(.save)
            let finished = model.lastFinished?.id == id ? model.lastFinished : nil
            outcome = finished == nil ? "Finished, but the recording may not have saved." : "Saved."
            let ranking = model.capabilities.beatToBeat ? finished?.resonance : nil
            voice.say(finished == nil ? "Done, but check the phone." : Self.doneLine(ranking))
        } catch {
            // In a fresh task: a cancelled one makes GRDB's async reads throw, losing the save.
            await Task { await abort(recordingId: id) }.value
        }
    }

    /// What a saved run ends with: the resonance finder's answer first when its recording ranks
    /// two or more rates (straplog-9fr.10), so it is heard with eyes closed.
    static func doneLine(_ ranking: ResonanceRanking?) -> String {
        guard let ranking else { return "Done. Recording saved." }
        return "Done. Largest swing at \(SpokenRate.words(ranking.best.rate)). Recording saved."
    }

    private func abort(recordingId id: Int64) async {
        await model.stopPacer()
        if model.activeRecording?.id == id {
            await model.marker(label: TrainingScript.abortedLabel)
            await model.stop(.save)
        }
        outcome = "Stopped early."
        voice.say("Training stopped.")
    }

    private func refuse(_ reason: String) {
        outcome = reason
        voice.say(reason)
    }

    private func perform(_ step: TrainingStep, note: String?, recordingId id: Int64) async throws {
        try check(id)
        let startMs = clock.nowMs()
        self.step = step
        stepEndsAtMs = startMs + step.totalMs
        if !model.link.isConnected { voice.say(notConnected) }
        voice.say(step.say)
        await model.marker(label: step.label, note: note)
        guard let rate = step.pacerRate else {
            try await speak(step.lines, from: startMs, recordingId: id)
            try await sleep(untilMs: startMs + step.durationMs, recordingId: id)
            return
        }
        try await sleep(untilMs: startMs + step.leadInMs, recordingId: id)
        await model.startPacer(breathsPerMinute: rate, ratio: .equal)
        guard let pacer = model.pacer else { throw Stopped() }
        let plannedEnd = pacer.startedAtMs + step.durationMs
        stepEndsAtMs = plannedEnd
        try await speak(step.lines, from: pacer.startedAtMs, recordingId: id)
        while true {
            let turn = Self.endTurnMs(pacer, notBeforeMs: plannedEnd, nowMs: clock.nowMs())
            stepEndsAtMs = turn
            try await sleep(untilMs: turn - Self.turnGuardMs, recordingId: id)
            // Woke inside the last out-breath: stop. Woke after the turn: wait for the next one.
            if clock.nowMs() < turn { break }
        }
        await model.stopPacer()
    }

    /// The first in-breath turn of `pacer` at or after `notBeforeMs` and after `nowMs`.
    static func endTurnMs(_ pacer: BreathingPacer, notBeforeMs: Int64, nowMs: Int64) -> Int64 {
        let t0 = pacer.startedAtMs
        let period = pacer.periodMs
        // The tolerance keeps a whole number of breaths from rounding up to the next one.
        let planned = (Double(notBeforeMs - t0) / period - 1e-6).rounded(.up)
        let afterNow = (Double(nowMs - t0) / period).rounded(.down) + 1
        return t0 + Int64((max(planned, afterNow) * period).rounded())
    }

    private func speak(_ lines: [TrainingLine], from originMs: Int64, recordingId id: Int64) async throws {
        for line in lines {
            let due = originMs + line.afterMs
            try await sleep(untilMs: due, recordingId: id)
            if clock.nowMs() - due <= Self.staleLineMs { voice.say(line.text) }
        }
    }

    private func sleep(untilMs target: Int64, recordingId id: Int64) async throws {
        while true {
            try check(id)
            let left = target - clock.nowMs()
            if left <= 0 { return }
            await sleeper.sleep(forMs: min(left, Self.pollMs))
        }
    }

    private func check(_ id: Int64) throws {
        if Task.isCancelled || model.activeRecording?.id != id { throw Stopped() }
    }
}
