import Testing
@testable import StrapLog

@Suite("LaunchOptions")
struct LaunchOptionsTests {
    @Test("no arguments → real strap, persistent database")
    func defaults() {
        let o = LaunchOptions(arguments: ["StrapLog"])
        #expect(o.replayFixture == nil)
        #expect(o.replaySpeed == 1)
        #expect(!o.freshDatabase)
    }

    @Test("replay, speed and fresh database parse in any order")
    func replay() {
        let o = LaunchOptions(arguments: ["StrapLog", "-speed", "50", "-freshDatabase", "-replay", "resting"])
        #expect(o.replayFixture == "resting")
        #expect(o.replaySpeed == 50)
        #expect(o.freshDatabase)
    }

    @Test("bad or non-positive speed falls back to 1")
    func badSpeed() {
        #expect(LaunchOptions(arguments: ["-speed", "fast"]).replaySpeed == 1)
        #expect(LaunchOptions(arguments: ["-speed", "0"]).replaySpeed == 1)
        #expect(LaunchOptions(arguments: ["-speed"]).replaySpeed == 1)
    }
}
