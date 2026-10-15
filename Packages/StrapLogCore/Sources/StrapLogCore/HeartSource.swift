/// Anything that produces sensor events: the Polar adapter, a fixture replayer, a test script.
/// Only `StrapLog/Polar/` knows about the SDK; everything else sees this.
public protocol HeartSource: Sendable {
    func events() -> AsyncStream<SensorEvent>
    /// Turns the accelerometer stream on or off. The model asks for it only while recording,
    /// so an idle connection costs the strap no extra battery. Sources without one ignore it.
    func setMotionStreaming(_ on: Bool)
}

extension HeartSource {
    public func setMotionStreaming(_ on: Bool) {}

    /// Feed every event into `session` until the source finishes.
    public func pump(into session: RecordingSession) async throws {
        for await event in events() {
            try await session.ingest(event)
        }
    }
}
