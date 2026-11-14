/// One `aae21542` notification, about 32 Hz: raw PPG as little-endian int16 in bytes 0–1
/// (repeated in 2–3), accelerometer in 8–13, and a counter in byte 19 that steps by one.
/// Bytes 4–7 are not decoded yet.
public struct PpgPacket: Sendable, Equatable {
    /// What the PPG reads off the skin (seen on a wet cloth, 2026-11-10, with HR 0).
    public static let offSkinValue = Int(Int16.max)

    public var counter: UInt8
    public var value: Int

    public init(counter: UInt8, value: Int) {
        self.counter = counter
        self.value = value
    }

    /// nil unless exactly the 20 bytes the band sends.
    public init?(_ bytes: [UInt8]) {
        guard bytes.count == 20 else { return nil }
        counter = bytes[19]
        value = Int(Int16(bitPattern: UInt16(bytes[0]) | UInt16(bytes[1]) << 8))
    }

    public var isOffSkin: Bool { value == Self.offSkinValue }
}
