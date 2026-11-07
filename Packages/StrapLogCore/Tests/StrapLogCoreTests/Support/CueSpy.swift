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
    /// `lengthMs` of each cue, in order.
    private(set) var lengths: [Double] = []
    private(set) var stops = 0

    init(clock: FakeClock) { self.clock = clock }

    func cue(inhaling: Bool, lengthMs: Double) {
        cues.append(Cue(atMs: clock.nowMs(), inhaling: inhaling))
        lengths.append(lengthMs)
    }
    func pacerDidStop() { stops += 1 }
}
