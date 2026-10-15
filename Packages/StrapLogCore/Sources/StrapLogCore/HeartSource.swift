/// Anything that produces sensor events: the Polar adapter, a fixture replayer, a test script.
/// Only `StrapLog/Polar/` knows about the SDK; everything else sees this.
public protocol HeartSource: Sendable {
    func events() -> AsyncStream<SensorEvent>
}

extension HeartSource {
    /// Feed every event into `session` until the source finishes.
    public func pump(into session: RecordingSession) async throws {
        for await event in events() {
            try await session.ingest(event)
        }
    }
}
