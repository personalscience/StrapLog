/// How `PacerClock` waits for the next turn. Injectable so tests never really wait.
public protocol PacerSleeper: Sendable {
    /// Returns when `ms` have passed or the task is cancelled, whichever is first.
    func sleep(forMs ms: Int64) async
}
