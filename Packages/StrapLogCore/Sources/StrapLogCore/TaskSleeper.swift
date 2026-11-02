/// `PacerSleeper` on `Task.sleep`, tight enough that a cue lands on the breath it marks.
public struct TaskSleeper: PacerSleeper {
    public init() {}

    public func sleep(forMs ms: Int64) async {
        try? await Task.sleep(for: .milliseconds(ms), tolerance: .milliseconds(20))
    }
}
