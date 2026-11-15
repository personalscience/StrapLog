/// Something a training step says partway through: `afterMs` from the step's origin (the pacer's
/// `t0` for a paced step, the step's start otherwise).
public struct TrainingLine: Sendable, Equatable {
    public let afterMs: Int64
    public let text: String

    public init(afterMs: Int64, text: String) {
        self.afterMs = afterMs
        self.text = text
    }
}
