import Foundation
import Testing
@testable import StrapLogCore

/// Decoding the HR a strap broadcasts, against the Polar BLE SDK's own example bytes.
@Suite("StrapBroadcast")
struct StrapBroadcastTests {
    func decode(_ bytes: [UInt8]) -> StrapBroadcast? { StrapBroadcast(manufacturerData: Data(bytes)) }

    @Test("an HR block after a length-prefixed block (the SDK's OH1 example)")
    func afterOtherBlock() {
        #expect(decode([0x6b, 0x00, 0x72, 0x06, 0x7f, 0x44, 0x37, 0x00, 0x00, 0x00, 0x33, 0x00, 0x3c])
                == StrapBroadcast(heartRate: 60, contact: true, frameCounter: 4))
    }

    @Test("an HR block after two other blocks")
    func afterTwoBlocks() {
        #expect(decode([0x6b, 0x00, 0x72, 0x08, 0x97, 0xc9, 0xc3, 0x00, 0x00, 0x00, 0x00, 0x00,
                        0x7a, 0x01, 0x03, 0x33, 0x00, 0x00])
                == StrapBroadcast(heartRate: 0, contact: true, frameCounter: 4))
    }

    @Test("a lone 4-byte block takes its fourth byte; a lone 3-byte block its third")
    func loneBlocks() {
        #expect(decode([0x6b, 0x00, 0x2b, 0x0b, 0xb6, 0xac])
                == StrapBroadcast(heartRate: 0xac, contact: true, frameCounter: 2))
        #expect(decode([0x6b, 0x00, 0x01, 0x00, 0x48])
                == StrapBroadcast(heartRate: 72, contact: false, frameCounter: 0))
    }

    @Test("no HR block, another company, or too short: nothing")
    func nothing() {
        #expect(decode([0x6b, 0x00, 0x72, 0x08, 0x97, 0xc9, 0xc3, 0x00, 0x00, 0x00, 0x00, 0x00]) == nil)
        #expect(decode([0x6b, 0x01, 0x2b, 0x0b, 0xb6, 0xac]) == nil)
        #expect(decode([0x6b]) == nil)
        #expect(decode([0x6b, 0x00, 0x72]) == nil, "a block cut off before its length")
    }

    @Test("our strap by id, any H10 before an id is known, never another device")
    func matching() {
        #expect(StrapBroadcast.isStrap(named: "Polar H10 A1B2C3D4", strapId: "a1b2c3d4"))
        #expect(!StrapBroadcast.isStrap(named: "Polar H10 0000FFFF", strapId: "A1B2C3D4"))
        #expect(StrapBroadcast.isStrap(named: "Polar H10 0000FFFF", strapId: nil))
        #expect(!StrapBroadcast.isStrap(named: "Polar OH1 A1B2C3D4", strapId: nil))
        #expect(!StrapBroadcast.isStrap(named: nil, strapId: nil))
    }

    @Test("no contact or a zero HR shows as --; the caption says where HR comes from")
    func text() {
        #expect(StrapBroadcast(heartRate: 61, contact: true, frameCounter: 0).heartRateText == "61")
        #expect(StrapBroadcast(heartRate: 61, contact: false, frameCounter: 0).heartRateText == "--")
        #expect(StrapBroadcast(heartRate: 0, contact: true, frameCounter: 0).heartRateText == "--")
        #expect(StrapBroadcast.caption(for: nil) == "Looking for the H10…")
        #expect(StrapBroadcast.caption(for: StrapBroadcast(heartRate: 0, contact: false, frameCounter: 0))
                == "No skin contact")
    }
}
