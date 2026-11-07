/// Decides when a wanted strap stream (ACC, ECG) needs starting again. The Polar SDK's
/// `bleSdkFeatureReady` is not a dependable trigger: it is polled against a 10 s deadline on a
/// main-runloop timer and can be missed after a reconnect or a restoration relaunch, and a
/// stream that errors or simply ends is otherwise never retried (straplog-4f1: motion lost for
/// the rest of a recording after a relaunch, and after a reconnect overnight).
///
/// Ridden on heart-rate notifications, no timer: while connected they arrive about once a second.
/// A stream is due when it was never attempted, when its last attempt ended `retryMs` ago, or
/// when an attempt still running has delivered nothing for `stallMs`.
public struct StreamWatchdog: Sendable {
    public static let defaultRetryMs: Int64 = 5_000
    public static let defaultStallMs: Int64 = 10_000

    private let retryMs: Int64
    private let stallMs: Int64
    /// The latest attempt or delivery, nil when never attempted since the last `reset`.
    private var lastSignMs: Int64?
    private var running = false
    private var generation = 0

    public init(retryMs: Int64 = defaultRetryMs, stallMs: Int64 = defaultStallMs) {
        self.retryMs = retryMs
        self.stallMs = stallMs
    }

    public func restartDue(atMs: Int64) -> Bool {
        guard let lastSignMs else { return true }
        return atMs - lastSignMs >= (running ? stallMs : retryMs)
    }

    /// A start was sent; returns its generation, to pass back to `ended`.
    public mutating func attempted(atMs: Int64) -> Int {
        generation += 1
        lastSignMs = atMs
        running = true
        return generation
    }

    public mutating func received(atMs: Int64) {
        lastSignMs = atMs
    }

    /// The attempt `generation` finished (error or end of stream). A superseded attempt's end is ignored.
    public mutating func ended(generation: Int, atMs: Int64) {
        guard generation == self.generation else { return }
        lastSignMs = atMs
        running = false
    }

    /// Disconnected or no longer wanted: the next wanted connection starts at once.
    public mutating func reset() {
        generation += 1
        lastSignMs = nil
        running = false
    }
}
