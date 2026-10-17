import Testing
@testable import StrapLogCore

/// When the Watch and the phone's alert buzz, and which marker the one Watch button makes.
@Suite("LinkAlarm and next marker")
struct LinkAlarmTests {
    func status(linked: Bool = true, contact: Bool? = true, beatGap: Bool = false, startedAtMs: Int64 = 0,
                lastMarker: String? = nil) -> LiveStatus {
        LiveStatus(name: "n", activity: "other", startedAtMs: startedAtMs, heartRate: 60, contact: contact,
                   linked: linked, alpha1: nil, rmssd: nil, battery: 80, markers: ["a", "b", "end"],
                   markerCount: lastMarker == nil ? 0 : 1, lastMarkerLabel: lastMarker, lastMarkerText: lastMarker,
                   beatGap: beatGap)
    }

    /// Alarm verdicts of one fresh `LinkAlarm` over `statuses` (status, isStale).
    func alarms(_ statuses: [(LiveStatus?, Bool)]) -> [LinkProblem?] {
        var alarm = LinkAlarm()
        return statuses.map { alarm.update($0, isStale: $1) }
    }

    @Test("problems rank stale, disconnected, contact, beat gap")
    func ranking() {
        #expect(status().problem(isStale: false) == nil)
        #expect(status(beatGap: true).problem(isStale: false) == .beatGap)
        #expect(status(contact: false, beatGap: true).problem(isStale: false) == .contactLost)
        #expect(status(linked: false, contact: false).problem(isStale: false) == .disconnected)
        #expect(status(linked: false).problem(isStale: true) == .stale)
        #expect(status(contact: nil).problem(isStale: false) == nil, "a strap without the contact bit is fine")
    }

    @Test("strap removal buzzes once, even as contact loss turns into a disconnect; recovery re-arms")
    func onceUntilRecovered() {
        #expect(alarms([(status(), false), (status(contact: false), false), (status(contact: false, beatGap: true), false),
                        (status(linked: false), false), (status(linked: false), true), (status(), false),
                        (status(beatGap: true), false)])
                == [nil, .contactLost, nil, nil, nil, nil, .beatGap])
    }

    @Test("the first status seen, a new recording, and idle never buzz")
    func quietStarts() {
        #expect(alarms([(status(linked: false), false), (status(), false), (nil, false),
                        (status(linked: false, startedAtMs: 9), false), (status(startedAtMs: 9), false),
                        (status(startedAtMs: 9), true)])
                == [nil, nil, nil, nil, nil, .stale])
    }

    @Test("the next marker steps through the bar; the last repeats; a note starts over")
    func nextMarker() {
        #expect(status().nextMarker == "a")
        #expect(status(lastMarker: "a").nextMarker == "b")
        #expect(status(lastMarker: "end").nextMarker == "end")
        #expect(status(lastMarker: "knee twinge").nextMarker == "a")
        let bare = LiveStatus(name: "n", activity: "other", startedAtMs: 0, heartRate: nil, contact: nil, linked: true,
                              alpha1: nil, rmssd: nil, battery: nil, markers: [], markerCount: 0)
        #expect(bare.nextMarker == nil)
    }
}
