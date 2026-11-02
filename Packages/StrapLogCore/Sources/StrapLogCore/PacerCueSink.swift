/// What the pacer's turns are played on, separate from the screen: `PacerClock` calls it with
/// the phone locked too. The tap at each turn stays in `BreathingPacerView`, because haptics
/// only work in the foreground and a second caller here would double-tap.
@MainActor
public protocol PacerCueSink: AnyObject {
    /// The breath just turned, or the pacer just started.
    func cue(inhaling: Bool)
    /// The pacer stopped; release whatever `cue` acquired.
    func pacerDidStop()
}
