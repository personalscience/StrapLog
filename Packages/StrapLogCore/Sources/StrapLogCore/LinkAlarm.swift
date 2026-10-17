/// Decides when a `LinkProblem` should buzz: once when beats stop flowing during a recording,
/// not again while they stay stopped (a contact loss that turns into a disconnect buzzes once),
/// and never for the state a display first sees (a resumed recording still reconnecting).
public struct LinkAlarm: Sendable {
    private var recording: Int64?
    private var problem: LinkProblem?

    public init() {}

    /// The problem to alert on now, if any. `status` nil means idle.
    public mutating func update(_ status: LiveStatus?, isStale: Bool = false) -> LinkProblem? {
        guard let status else {
            recording = nil
            problem = nil
            return nil
        }
        let now = status.problem(isStale: isStale)
        defer {
            recording = status.startedAtMs
            problem = now
        }
        guard recording == status.startedAtMs, problem == nil else { return nil }
        return now
    }
}
