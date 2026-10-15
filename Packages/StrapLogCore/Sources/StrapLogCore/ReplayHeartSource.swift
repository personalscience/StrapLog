import Foundation

/// Replays a recorded RR series as ~1 Hz HR notifications, so the app runs in the
/// simulator and UI tests without a strap. Beats are grouped by the whole second in
/// which they end, as the H10 does. Receive times come from `clock`, so at `speed` > 1
/// the stored times are compressed and the data is only useful for checking the UI.
public struct ReplayHeartSource: HeartSource {
    public static let deviceId = "REPLAY"

    public let rrMs: [Double]
    public let speed: Double
    public let clock: any WallClock
    public let sleep: @Sendable (Duration) async -> Void

    public init(rrMs: [Double], speed: Double = 1, clock: any WallClock = SystemClock(),
                sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        precondition(speed > 0, "speed must be positive")
        self.rrMs = rrMs
        self.speed = speed
        self.clock = clock
        self.sleep = sleep
    }

    /// Reads the `rr_ms` array from a `Tests/fixtures/<rec>.json` file.
    public static func fixture(at url: URL, speed: Double = 1, clock: any WallClock = SystemClock())
        throws -> ReplayHeartSource
    {
        struct File: Decodable { let rr_ms: [Double] }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        return ReplayHeartSource(rrMs: file.rr_ms, speed: speed, clock: clock)
    }

    /// The notifications this replay emits, one per elapsed second, as RR lists in 1/1024 s.
    public var notifications: [[Int]] {
        var out: [[Int]] = []
        var current: [Int] = []
        var second = 1.0
        var endS = 0.0
        for rr in rrMs {
            endS += rr / 1000
            while endS > second {
                out.append(current)
                current = []
                second += 1
            }
            current.append(Int((rr * 1.024).rounded()))
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    public func events() -> AsyncStream<SensorEvent> {
        let notifications = self.notifications
        let tick = Duration.seconds(1 / speed)
        let (clock, sleep) = (self.clock, self.sleep)
        return AsyncStream { continuation in
            let task = Task {
                continuation.yield(SensorEvent(atMs: clock.nowMs(),
                                               .connected(deviceId: Self.deviceId, firmware: "replay")))
                continuation.yield(SensorEvent(atMs: clock.nowMs(), .battery(percent: 100)))
                var lastBpm = 60
                for rr1024 in notifications {
                    await sleep(tick)
                    if Task.isCancelled { break }
                    if let last = rr1024.last { lastBpm = Int((60 * 1024 / Double(last)).rounded()) }
                    continuation.yield(SensorEvent(atMs: clock.nowMs(),
                                                   .heartRate(bpm: lastBpm, contact: true, rr1024: rr1024)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
