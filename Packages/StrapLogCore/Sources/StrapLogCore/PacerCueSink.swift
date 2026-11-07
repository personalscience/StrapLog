/// What the pacer's turns are played on, separate from the screen: `PacerClock` calls it with
/// the phone locked too. The tap at each turn stays in `BreathingPacerView`, because haptics
/// only work in the foreground and a second caller here would double-tap.
@MainActor
public protocol PacerCueSink: AnyObject {
    /// The breath just turned, or the pacer just started. `lengthMs` is how long this half of
    /// the breath lasts in full, so a tone can fade across it.
    func cue(inhaling: Bool, lengthMs: Double)
    /// The pacer stopped; release whatever `cue` acquired.
    func pacerDidStop()
}
