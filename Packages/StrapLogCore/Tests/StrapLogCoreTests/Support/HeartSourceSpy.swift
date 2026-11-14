import Synchronization
@testable import StrapLogCore

/// A `FakeHeartSource` that also records each `setMotionStreaming`, `setECGStreaming` and `forgetDevice` call.
final class HeartSourceSpy: HeartSource {
    let inner: FakeHeartSource
    let capabilities: SensorCapabilities
    private let log = Mutex<[Bool]>([])
    private let ecgLog = Mutex<[Bool]>([])
    private let forgetCount = Mutex(0)

    init(_ inner: FakeHeartSource, capabilities: SensorCapabilities = SensorCapabilities()) {
        self.inner = inner
        self.capabilities = capabilities
    }

    var calls: [Bool] { log.withLock { $0 } }
    var ecgCalls: [Bool] { ecgLog.withLock { $0 } }
    var forgets: Int { forgetCount.withLock { $0 } }

    func events() -> AsyncStream<SensorEvent> { inner.events() }

    func setMotionStreaming(_ on: Bool) {
        log.withLock { $0.append(on) }
    }

    func setECGStreaming(_ on: Bool) {
        ecgLog.withLock { $0.append(on) }
    }

    func forgetDevice() {
        forgetCount.withLock { $0 += 1 }
    }
}
