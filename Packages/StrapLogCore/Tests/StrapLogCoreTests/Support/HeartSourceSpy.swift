import Synchronization
@testable import StrapLogCore

/// A `FakeHeartSource` that also records each `setMotionStreaming` and `forgetDevice` call.
final class HeartSourceSpy: HeartSource {
    let inner: FakeHeartSource
    private let log = Mutex<[Bool]>([])
    private let forgetCount = Mutex(0)

    init(_ inner: FakeHeartSource) {
        self.inner = inner
    }

    var calls: [Bool] { log.withLock { $0 } }
    var forgets: Int { forgetCount.withLock { $0 } }

    func events() -> AsyncStream<SensorEvent> { inner.events() }

    func setMotionStreaming(_ on: Bool) {
        log.withLock { $0.append(on) }
    }

    func forgetDevice() {
        forgetCount.withLock { $0 += 1 }
    }
}
