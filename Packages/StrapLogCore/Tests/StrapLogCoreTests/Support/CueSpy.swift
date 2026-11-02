import StrapLogCore

/// Records what a `PacerClock` cues, with the fake time of each cue.
@MainActor
final class CueSpy: PacerCueSink {
    struct Cue: Equatable {
        let atMs: Int64
        let inhaling: Bool
    }

    let clock: FakeClock
    private(set) var cues: [Cue] = []
    private(set) var stops = 0

    init(clock: FakeClock) { self.clock = clock }

    func cue(inhaling: Bool) { cues.append(Cue(atMs: clock.nowMs(), inhaling: inhaling)) }
    func pacerDidStop() { stops += 1 }
}
