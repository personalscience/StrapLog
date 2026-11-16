/// One standard Heart Rate Measurement (0x2A37) notification.
/// The band sends flags 0x10 when a beat landed in the last second (HR plus RR) and 0x00 when
/// not; it never reports skin contact, and off the arm it sends HR 0. Its RR fields are whole
/// milliseconds, not the spec's 1/1024 s (straplog-d1h).
public struct HeartRateMeasurement: Sendable, Equatable {
    public var bpm: Int
    /// nil when the sensor does not report contact (this band never does).
    public var contact: Bool?
    /// RR intervals in milliseconds, oldest first. The spec says 1/1024 s, but this band sends ms:
    /// its RR sums to the elapsed time at a ratio of 1.00, not 1.024, with 0.3% of beats missed,
    /// and HR from RR read as 1/1024 runs 2.4% high against an H10 (261113, 261115).
    public var rrMs: [Int]

    public init(bpm: Int, contact: Bool?, rrMs: [Int]) {
        self.bpm = bpm
        self.contact = contact
        self.rrMs = rrMs
    }

    /// Parses the bytes per the Bluetooth Heart Rate Service spec, all but RR's unit; nil if too short.
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
        rrMs = []
        if flags & 0x10 != 0 {
            while i + 1 < bytes.count {
                rrMs.append(Int(bytes[i]) | Int(bytes[i + 1]) << 8)
                i += 2
            }
        }
    }
}
