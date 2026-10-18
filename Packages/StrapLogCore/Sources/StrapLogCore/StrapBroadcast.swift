import Foundation

/// One HR reading a Polar strap broadcasts in its BLE advertisements, read without connecting:
/// what the Watch shows when the phone is gone (`HeartRateSourcePolicy`). About 1 Hz, HR only,
/// no RR. A port of the Polar BLE SDK's `BleAdvertisementContent.processManufacturerData` and
/// `BlePolarHrAdvertisement` (8.4.0).
public struct StrapBroadcast: Sendable, Equatable {
    public let heartRate: Int
    public let contact: Bool
    /// Bits 2–4 of the HR block's first byte; a change means a new reading.
    public let frameCounter: UInt8

    static let polarCompanyId: UInt16 = 0x006B
    static let namePrefix = "Polar H10"

    public init(heartRate: Int, contact: Bool, frameCounter: UInt8) {
        self.heartRate = heartRate
        self.contact = contact
        self.frameCounter = frameCounter
    }

    /// The reading in an advertisement's manufacturer data (`CBAdvertisementDataManufacturerDataKey`),
    /// or nil when it is not Polar's or carries no HR block. Data: a little-endian company id,
    /// then either one 3- or 4-byte HR block or a run of blocks, where bit 6 of a block's first
    /// byte marks a length-prefixed non-HR block. The last HR block wins, as in the SDK.
    public init?(manufacturerData data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 2, UInt16(bytes[0]) | UInt16(bytes[1]) << 8 == Self.polarCompanyId else { return nil }
        let content = Array(bytes.dropFirst(2))
        var block: ArraySlice<UInt8>?
        if content.count == 3 || content.count == 4 {
            block = content[...]
        } else {
            var offset = 0
            while offset < content.count {
                if content[offset] & 0x40 == 0 {
                    if offset + 3 <= content.count { block = content[offset...] }
                    offset += 3
                } else {
                    guard offset + 1 < content.count else { break }
                    offset += Int(content[offset + 1]) + 2
                }
            }
        }
        guard let block else { return nil }
        let first = block[block.startIndex]
        // The SDK's slow average: the fourth byte of a 4-byte block, else the third.
        let hr = block.count == 4 ? block[block.startIndex + 3] : block[block.startIndex + 2]
        self.init(heartRate: Int(hr), contact: first & 0x02 != 0, frameCounter: (first & 0x1C) >> 2)
    }

    /// Whether an advertised local name (`Polar H10 A1B2C3D4`) is our strap: the one with
    /// `strapId`, or any H10 while no id is known yet.
    public static func isStrap(named name: String?, strapId: String?) -> Bool {
        guard let name, name.hasPrefix(namePrefix) else { return false }
        guard let strapId else { return true }
        return name.split(separator: " ").last?.uppercased() == strapId.uppercased()
    }

    public var heartRateText: String { contact && heartRate > 0 ? String(heartRate) : "--" }

    /// The line under strap HR, saying where it comes from; `reading` nil while none is fresh.
    public static func caption(for reading: StrapBroadcast?) -> String {
        guard let reading else { return "Looking for the H10…" }
        return reading.contact ? "From the H10 · no iPhone" : "No skin contact"
    }
}
