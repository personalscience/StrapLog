/// What `BreathTracker` makes of the breathing so far, after each accelerometer batch.
public struct BreathReading: Sendable, Equatable {
    /// Time of the latest sample, Unix epoch ms.
    public let atMs: Int64
    /// Lung fill as measured, 0 empty to 1 full, scaled to the last few breaths; nil until the
    /// tracker has found the breath, and while the body moves.
    public let volume: Double?
    /// False while movement swamps the breath: the user should hold still.
    public let still: Bool
    /// How closely the breath follows the pacer over the last minute: the correlation of
    /// measured and paced lung fill, -1 to 1; nil until there is half a minute of it.
    public let inStep: Double?

    public init(atMs: Int64, volume: Double?, still: Bool, inStep: Double?) {
        self.atMs = atMs
        self.volume = volume
        self.still = still
        self.inStep = inStep
    }

    /// One line for under the pacer.
    public var caption: String {
        if !still { return "Hold still to see your breath" }
        guard volume != nil else { return "Finding your breath…" }
        guard let inStep else { return "Following your breath" }
        return "In step \(Int((max(0, inStep) * 100).rounded()))%"
    }
}
