import Foundation
import Testing
@testable import HRVKit

@Suite("TimeDomain")
struct TimeDomainTests {
    @Test("constant RR: SDNN 0, RMSSD 0, LnRMSSD undefined")
    func constant() {
        let rr = [Double](repeating: 800, count: 100)
        #expect(TimeDomain.sdnn(rr) == 0)
        #expect(TimeDomain.rmssd(rr) == 0)
        #expect(TimeDomain.lnRMSSD(rr) == nil)
        #expect(TimeDomain.meanHR(rr) == 75)
    }

    @Test("alternating RR: RMSSD equals the step")
    func alternating() {
        let rr = (0..<100).map { $0.isMultiple(of: 2) ? 800.0 : 900.0 }
        #expect(TimeDomain.rmssd(rr) == 100)
        #expect(abs(TimeDomain.lnRMSSD(rr)! - log(100)) < 1e-12)
        // 50 + 50 values each 50 from the mean of 850: ss = 100·2500, ddof 1.
        #expect(abs(TimeDomain.sdnn(rr)! - (250_000.0 / 99).squareRoot()) < 1e-9)
    }

    @Test("SDNN uses ddof = 1")
    func sdnnDdof() {
        #expect(TimeDomain.sdnn([1, 3]) == 2.0.squareRoot())
    }

    @Test("too-short and empty inputs return nil")
    func degenerate() {
        #expect(TimeDomain.rmssd([]) == nil)
        #expect(TimeDomain.rmssd([800]) == nil)
        #expect(TimeDomain.sdnn([800]) == nil)
        #expect(TimeDomain.meanHR([]) == nil)
        #expect(TimeDomain.lnRMSSD([]) == nil)
    }
}
