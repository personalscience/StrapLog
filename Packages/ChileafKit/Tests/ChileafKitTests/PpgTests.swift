import Testing
@testable import ChileafKit

@Suite("PPG (aae21542)")
struct PpgTests {
    @Test("value is little-endian int16 in bytes 0–1, counter in byte 19 (11-03 probe)")
    func packet() {
        #expect(PpgPacket(hex("501d501d0083120020fac008000b4c14060000f5")) == PpgPacket(counter: 0xf5, value: 7504))
        #expect(PpgPacket(hex("501d")) == nil)
    }

    @Test("off the skin it pins at 32767")
    func offSkin() {
        var b = [UInt8](repeating: 0, count: 20)
        b[0] = 0xff; b[1] = 0x7f
        #expect(PpgPacket(b)?.isOffSkin == true)
    }

    /// Counter sequences copied from the 11-10 capture's four anomalies.
    @Test("drops immediate repeats and rewound re-sends; keeps real gaps and wraparound")
    func dedupe() {
        var d = PpgDeduper()
        let rewind: [UInt8] = [143, 144, 145, 145, 146, 147, 148, 149, 150, 151, 152,
                               138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154]
        #expect(rewind.filter { d.accept($0) } == Array(143...154))
        let gap: [UInt8] = [170, 171, 172, 189, 190]
        d.reset()
        #expect(gap.filter { d.accept($0) } == gap)
        let wrap: [UInt8] = [254, 255, 0, 1, 255, 2]
        d.reset()
        #expect(wrap.filter { d.accept($0) } == [254, 255, 0, 1, 2])
    }
}
