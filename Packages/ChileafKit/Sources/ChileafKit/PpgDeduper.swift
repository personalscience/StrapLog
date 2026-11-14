/// Drops the PPG packets the band sends twice. Now and then it re-sends the last 14–15 packets,
/// identical, after the newest one (11-10 capture: rewinds at 86 s, 109 s, 295 s), or repeats
/// one at once. A packet is kept only if its counter is ahead of the newest kept, mod 256.
/// A forward jump (seen: +17) is real loss and is kept; the stored counters show the gap.
public struct PpgDeduper: Sendable {
    private var newest: UInt8?

    public init() {}

    /// Whether `counter` is new. Call `reset` on every (re)connection.
    public mutating func accept(_ counter: UInt8) -> Bool {
        guard let newest else {
            self.newest = counter
            return true
        }
        let ahead = counter &- newest
        guard ahead != 0, ahead < 128 else { return false }
        self.newest = counter
        return true
    }

    public mutating func reset() {
        newest = nil
    }
}
