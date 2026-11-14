import Testing
@testable import ChileafKit

@Suite("Heart Rate Measurement (0x2A37)")
struct HeartRateMeasurementTests {
    @Test("HR only, no contact reported (11-10 capture: 0049)")
    func hrOnly() throws {
        let m = try #require(HeartRateMeasurement(hex("0049")))
        #expect(m == HeartRateMeasurement(bpm: 73, contact: nil, rr1024: []))
    }

    @Test("HR plus several RR, little-endian, in 1/1024 s (11-10 capture)")
    func withRR() throws {
        let m = try #require(HeartRateMeasurement(hex("1048a1037a034d048203")))
        #expect(m.bpm == 72)
        #expect(m.rr1024 == [0x03a1, 0x037a, 0x044d, 0x0382])
    }

    @Test("16-bit HR, contact bits and energy expended per the spec")
    func spec() throws {
        let m = try #require(HeartRateMeasurement([0x1f, 0x2c, 0x01, 0x10, 0x00, 0x00, 0x04]))
        #expect(m == HeartRateMeasurement(bpm: 300, contact: true, rr1024: [1024]))
        #expect(HeartRateMeasurement([0x04, 60])?.contact == false)
    }

    @Test("too short is nil, not a crash")
    func short() {
        #expect(HeartRateMeasurement([]) == nil)
        #expect(HeartRateMeasurement([0x01, 0x2c]) == nil)
    }
}
