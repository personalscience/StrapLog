import Testing
@testable import StrapLog

@Suite("App harness")
struct HarnessTests {
    @Test("App unit-test harness runs and links the Polar SDK")
    func harnessRuns() {
        #expect(PolarSDKLink.featureCount > 0)
    }
}
