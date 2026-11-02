/// Tells a `PacerCueSink` about each turn of the breath, independent of any view: a locked
/// screen renders nothing, so nothing else would notice. A sleeping task rather than a ride on
/// BLE notifications, because the pacer also runs with no strap and no recording.
@MainActor
public final class PacerClock {
    private let clock: any WallClock
    private let sleeper: any PacerSleeper
    private let sink: any PacerCueSink
    private var task: Task<Void, Never>?

    public init(clock: any WallClock, sleeper: any PacerSleeper, sink: any PacerCueSink) {
        self.clock = clock
        self.sleeper = sleeper
        self.sink = sink
    }

    /// Cues `pacer`'s current half of the breath at once, then each turn, replacing any earlier
    /// run. Each wait is worked out afresh from wall time, so nothing drifts. A late wake cues
    /// the half it landed in, once, instead of the turns it missed.
    public func run(_ pacer: BreathingPacer) {
        task?.cancel()
        task = Task { [clock, sleeper, sink] in
            var next = pacer.nextTransition(afterMs: clock.nowMs())
            sink.cue(inhaling: !next.inhaling)
            while true {
                await sleeper.sleep(forMs: next.atMs - clock.nowMs())
                if Task.isCancelled { return }
                let now = clock.nowMs()
                guard now >= next.atMs else { continue }
                next = pacer.nextTransition(afterMs: now)
                sink.cue(inhaling: !next.inhaling)
            }
        }
    }

    public func stop() {
        guard let task else { return }
        task.cancel()
        self.task = nil
        sink.pacerDidStop()
    }
}
