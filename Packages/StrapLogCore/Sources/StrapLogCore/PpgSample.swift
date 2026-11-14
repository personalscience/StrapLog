/// One raw PPG reading from an optical sensor (the BaroShift armband's, about 32 Hz), stamped
/// with the phone's receipt of the packet that carried it. `counter` is the sensor's own packet
/// counter (0–255, steps by one), so a gap in it is a lost packet; duplicates are dropped by the
/// source before this point.
public struct PpgSample: Sendable, Equatable {
    public var receivedAtMs: Int64
    public var counter: Int
    public var value: Int

    public init(receivedAtMs: Int64, counter: Int, value: Int) {
        self.receivedAtMs = receivedAtMs
        self.counter = counter
        self.value = value
    }
}
