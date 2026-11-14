/// One standard Heart Rate Measurement (0x2A37) notification.
/// The band sends flags 0x10 when a beat landed in the last second (HR plus RR) and 0x00 when
/// not; it never reports skin contact, and off the arm it sends HR 0.
public struct HeartRateMeasurement: Sendable, Equatable {
    public var bpm: Int
    /// nil when the sensor does not report contact (this band never does).
    public var contact: Bool?
    /// RR intervals in 1/1024 s, oldest first.
    public var rr1024: [Int]

    public init(bpm: Int, contact: Bool?, rr1024: [Int]) {
        self.bpm = bpm
        self.contact = contact
        self.rr1024 = rr1024
    }

    /// Parses per the Bluetooth Heart Rate Service spec; nil if the bytes are too short.
    public init?(_ bytes: [UInt8]) {
        guard let flags = bytes.first else { return nil }
        var i = 1
        if flags & 0x01 != 0 {
            guard bytes.count >= i + 2 else { return nil }
            bpm = Int(bytes[i]) | Int(bytes[i + 1]) << 8
            i += 2
        } else {
            guard bytes.count >= i + 1 else { return nil }
            bpm = Int(bytes[i])
            i += 1
        }
        switch (flags >> 1) & 0x03 {
        case 0x02: contact = false
        case 0x03: contact = true
        default: contact = nil
        }
        if flags & 0x08 != 0 { i += 2 }  // energy expended
        rr1024 = []
        if flags & 0x10 != 0 {
            while i + 1 < bytes.count {
                rr1024.append(Int(bytes[i]) | Int(bytes[i + 1]) << 8)
                i += 2
            }
        }
    }
}
