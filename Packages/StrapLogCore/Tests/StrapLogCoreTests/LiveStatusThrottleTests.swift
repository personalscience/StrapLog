import Testing
@testable import StrapLogCore

@Suite("LiveStatusThrottle")
struct LiveStatusThrottleTests {
    func status(hr: Int? = 60, linked: Bool = true, contact: Bool? = true, markerCount: Int = 0,
                startedAtMs: Int64 = 0) -> LiveStatus {
        LiveStatus(name: "n", activity: "other", startedAtMs: startedAtMs, heartRate: hr, contact: contact,
                   linked: linked, alpha1: nil, rmssd: nil, battery: 80, markers: ["a"], markerCount: markerCount)
    }

    /// Admit verdicts of one fresh throttle over `offers` (status, atMs).
    func verdicts(_ offers: [(LiveStatus?, Int64)], minIntervalMs: Int64 = 10_000) -> [Bool] {
        var throttle = LiveStatusThrottle(minIntervalMs: minIntervalMs)
        return offers.map { throttle.admit($0, atMs: $1) }
    }

    @Test("the first value goes out, even nil, so a launch ends a leftover activity; repeats never do")
    func first() {
        #expect(verdicts([(nil, 0), (nil, 60_000)]) == [true, false])
    }

    @Test("routine HR changes go out at most every minIntervalMs")
    func routine() {
        #expect(verdicts([(status(hr: 60), 0), (status(hr: 61), 5_000), (status(hr: 62), 9_999),
                          (status(hr: 62), 10_000), (status(hr: 62), 30_000)])
                == [true, false, false, true, false])
    }

    @Test("start, stop, link, contact and marker changes go out at once")
    func urgent() {
        #expect(verdicts([(status(), 0), (status(linked: false), 1), (status(), 2), (status(contact: false), 3),
                          (status(contact: false, markerCount: 1), 4), (nil, 5), (status(startedAtMs: 6), 6),
                          (status(startedAtMs: 7), 7)])
                == Array(repeating: true, count: 8))
    }
}
