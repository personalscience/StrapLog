import StrapLogCore
import Testing
@testable import ChileafKit

@Suite("Vendor frames (aae28f01)")
struct VendorFrameTests {
    @Test("accelerometer frame from the 11-03 probe: checksum a4, x −1472, y 2240, z 2880")
    func accel() {
        let bytes = hex("ff0a0c40fac008400ba4")
        #expect(VendorFrame.checksum(bytes.dropLast()) == 0xa4)
        #expect(VendorFrame.parse(bytes) == .accel(AccelCounts(x: -1472, y: 2240, z: 2880)))
    }

    @Test("at rest the vector is about 1 g at the inferred 4096 counts/g")
    func scale() {
        let mg = AccelCounts(x: -1472, y: 2240, z: 2880).milliG
        let g = (Double(mg.x * mg.x + mg.y * mg.y + mg.z * mg.z)).squareRoot()
        #expect(abs(g - 1000) < 60)
    }

    @Test("temperature frame from the 11-10 capture: 31.5 / 32.9 / 36.5 °C, big-endian")
    func temperature() {
        #expect(VendorFrame.parse(hex("ff0a38013b0149016df1"))
                == .temperature(TemperatureReading(ambientDeci: 315, skinDeci: 329, bodyDeci: 365)))
        #expect(VendorFrame.parse(hex("ff0a380126013a016bcb"))
                == .temperature(TemperatureReading(ambientDeci: 294, skinDeci: 314, bodyDeci: 363)))
    }

    @Test("other frame types pass the checksum and come back whole", arguments: [
        "ff0d150000000000000000795c",
        "ff1775000f1a0d013d017fffffff002336b00012ec8dca",
    ])
    func others(_ h: String) throws {
        guard case .other(let type, let payload) = try #require(VendorFrame.parse(hex(h))) else {
            Issue.record("decoded as accel"); return
        }
        #expect(type == hex(h)[2])
        #expect(payload.count == hex(h).count - 4)
    }

    @Test("a corrupt byte, wrong length or missing header is rejected")
    func rejects() {
        #expect(VendorFrame.parse(hex("ff0a0c40fac008400ba5")) == nil)
        #expect(VendorFrame.parse(hex("ff0b0c40fac008400ba4")) == nil)
        #expect(VendorFrame.parse(hex("fe0a0c40fac008400ba4")) == nil)
        #expect(VendorFrame.parse([]) == nil)
    }
}
