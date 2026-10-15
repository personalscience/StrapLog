import Synchronization
@testable import StrapLogCore

/// A `FakeHeartSource` that also records each `setMotionStreaming` call.
final class MotionSwitchSpy: HeartSource {
    let inner: FakeHeartSource
    private let log = Mutex<[Bool]>([])

    init(_ inner: FakeHeartSource) {
        self.inner = inner
    }

    var calls: [Bool] { log.withLock { $0 } }

    func events() -> AsyncStream<SensorEvent> { inner.events() }

    func setMotionStreaming(_ on: Bool) {
        log.withLock { $0.append(on) }
    }
}
