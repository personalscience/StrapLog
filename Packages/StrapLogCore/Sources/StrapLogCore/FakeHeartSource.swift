import Synchronization

/// Plays a script of waits and payloads. The clock advances lazily, as the consumer
/// pulls each event, so session calls interleaved with a pump see consistent times.
public struct FakeHeartSource: HeartSource {
    public enum Step: Sendable {
        case wait(ms: Int64)
        case emit(SensorEvent.Payload)
    }

    public let script: [Step]
    public let clock: FakeClock

    public init(clock: FakeClock, script: [Step]) {
        self.clock = clock
        self.script = script
    }

    public func events() -> AsyncStream<SensorEvent> {
        let cursor = Cursor(script: script, clock: clock)
        return AsyncStream(unfolding: { cursor.next() })
    }
}

private final class Cursor: Sendable {
    private let script: [FakeHeartSource.Step]
    private let clock: FakeClock
    private let position = Mutex(0)

    init(script: [FakeHeartSource.Step], clock: FakeClock) {
        self.script = script
        self.clock = clock
    }

    func next() -> SensorEvent? {
        position.withLock { i in
            while i < script.count {
                defer { i += 1 }
                switch script[i] {
                case .wait(let ms): clock.advance(byMs: ms)
                case .emit(let payload): return SensorEvent(atMs: clock.nowMs(), payload)
                }
            }
            return nil
        }
    }
}
