import Testing
@testable import HRVKit

@Suite("Harness")
struct HarnessTests {
    @Test("HRVKit test harness runs")
    func harnessRuns() {
        #expect(HRVKit.version.isEmpty == false)
    }
}
