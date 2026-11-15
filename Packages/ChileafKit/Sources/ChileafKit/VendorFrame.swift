/// One `aae28f01` notification: `ff`, total length, type, payload, checksum, where the checksum is
/// `((-sum(all bytes but the last)) & 0xff) ^ 0x3a`. Every one of 18,476 frames in the 11-10
/// capture passed it, and none held more than one frame.
import StrapLogCore

public enum VendorFrame: Sendable, Equatable {
    /// Type 0x0c, about 51 Hz: one accelerometer sample, x, y, z as little-endian int16.
    case accel(AccelCounts)
    /// Type 0x38, once a second (values change about once a minute): three temperatures in
    /// 0.1 °C as **big-endian** int16, unlike the accelerometer. Big-endian is the only order
    /// that gives plausible values: all 570 frames in the 11-03 and 11-10 captures read 23–37 °C.
    case temperature(TemperatureReading)
    /// Types not decoded yet (0x15, 0x75, 0x47 seen), kept whole.
    case other(type: UInt8, payload: [UInt8])

    static let accelType: UInt8 = 0x0c
    static let temperatureType: UInt8 = 0x38

    /// nil for anything that is not a well-formed frame with a valid checksum.
    public static func parse(_ bytes: [UInt8]) -> VendorFrame? {
        guard bytes.count >= 4, bytes[0] == 0xff, Int(bytes[1]) == bytes.count,
              checksum(bytes.dropLast()) == bytes[bytes.count - 1] else { return nil }
        let type = bytes[2]
        let payload = Array(bytes[3..<(bytes.count - 1)])
        if type == accelType, payload.count == 6 {
            return .accel(AccelCounts(x: int16(payload, 0), y: int16(payload, 2), z: int16(payload, 4)))
        }
        if type == temperatureType, payload.count == 6 {
            return .temperature(TemperatureReading(ambientDeci: int16BE(payload, 0), skinDeci: int16BE(payload, 2),
                                                   bodyDeci: int16BE(payload, 4)))
        }
        return .other(type: type, payload: payload)
    }

    static func checksum(_ bytes: some Sequence<UInt8>) -> UInt8 {
        let sum = bytes.reduce(0) { $0 &+ $1 }
        return (0 &- sum) ^ 0x3a
    }

    private static func int16(_ b: [UInt8], _ i: Int) -> Int {
        Int(Int16(bitPattern: UInt16(b[i]) | UInt16(b[i + 1]) << 8))
    }

    private static func int16BE(_ b: [UInt8], _ i: Int) -> Int {
        Int(Int16(bitPattern: UInt16(b[i]) << 8 | UInt16(b[i + 1])))
    }
}
