import Testing
@testable import StrapLogCore

/// Phone first, the strap only while the phone has no fresh HR, nothing off screen.
@Suite("HeartRateSourcePolicy")
struct HeartRateSourcePolicyTests {
    let clock = FakeClock()
    var policy = HeartRateSourcePolicy()

    func status(linked: Bool = true, heartRate: Int? = 60) -> LiveStatus {
        LiveStatus(name: "n", activity: "other", startedAtMs: 0, heartRate: heartRate, contact: true, linked: linked,
                   alpha1: nil, rmssd: nil, battery: 80, markers: [], markerCount: 0)
    }

    mutating func update(foreground: Bool = true, reachable: Bool = true, _ status: LiveStatus?,
                         receivedAgoMs: Int64? = 0) -> HeartRateSource {
        let now = clock.nowMs()
        return policy.update(isForeground: foreground, isReachable: reachable, status: status,
                             receivedAtMs: receivedAgoMs.map { now - $0 }, nowMs: now)
    }

    @Test("a fresh, linked, reachable phone wins")
    mutating func phone() {
        #expect(update(status()) == .phone)
    }

    @Test("the strap takes over at once when the phone is unreachable, idle, unlinked or quiet")
    mutating func strap() {
        #expect(update(reachable: false, status()) == .strap)
        policy = HeartRateSourcePolicy()
        #expect(update(nil, receivedAgoMs: nil) == .strap)
        policy = HeartRateSourcePolicy()
        #expect(update(status(linked: false, heartRate: nil)) == .strap)
        policy = HeartRateSourcePolicy()
        #expect(update(status(), receivedAgoMs: HeartRateSourcePolicy.phoneQuietAfterMs + 1) == .strap)
    }

    @Test("a phone gone quiet hands over to the strap")
    mutating func goesQuiet() {
        #expect(update(status()) == .phone)
        clock.advance(byMs: HeartRateSourcePolicy.phoneQuietAfterMs + 1)
        #expect(update(status(), receivedAgoMs: HeartRateSourcePolicy.phoneQuietAfterMs + 1) == .strap)
    }

    @Test("back to the phone only on a status heard after the strap took over, not on reachability")
    mutating func hysteresis() {
        #expect(update(reachable: false, status(), receivedAgoMs: 5_000) == .strap)
        clock.advance(byMs: 1_000)
        #expect(update(reachable: true, status(), receivedAgoMs: 6_000) == .strap, "the old status is not news")
        #expect(update(reachable: true, status()) == .phone)
    }

    @Test("off screen is idle, and coming back starts over")
    mutating func idle() {
        #expect(update(reachable: false, status()) == .strap)
        #expect(update(foreground: false, status()) == .idle)
        #expect(update(status(), receivedAgoMs: 1_000) == .phone)
    }
}
