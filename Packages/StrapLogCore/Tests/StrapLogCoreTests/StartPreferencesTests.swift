import Foundation
import Testing
@testable import StrapLogCore

@Suite("StartPreferences")
struct StartPreferencesTests {
    let defaults: UserDefaults
    let suite = "StartPreferencesTests-\(UUID().uuidString)"
    let pacific = TimeZone(identifier: "America/Los_Angeles")!
    /// 2025-10-15 22:00 PDT.
    let tenPM = Date(timeIntervalSince1970: 1_760_590_800)

    init() {
        defaults = UserDefaults(suiteName: suite)!
    }

    @Test("unset keys give the Start screen's defaults: stop at the next 06:30")
    func defaultsWhenUnset() {
        defer { defaults.removePersistentDomain(forName: suite) }
        let plan = StartPreferences.plan(from: defaults, after: tenPM, timeZone: .current)
        let wake = Date(timeIntervalSince1970: Double(plan.wakeAtMs!) / 1000)
        #expect(Calendar.current.dateComponents([.hour, .minute], from: wake) == DateComponents(hour: 6, minute: 30))
        #expect(wake > tenPM && wake.timeIntervalSince(tenPM) <= 86_400)
    }

    @Test("saved choices win: a saved wake time, or no wake time when stop-at-wake is off")
    func savedChoices() {
        defer { defaults.removePersistentDomain(forName: suite) }
        // 2023-11-14 14:13 PST, as a time picker stores it.
        defaults.set(Date(timeIntervalSince1970: 1_700_000_000).timeIntervalSinceReferenceDate,
                     forKey: StartPreferences.wakeAtKey)
        #expect(StartPreferences.plan(from: defaults, after: tenPM, timeZone: pacific).wakeAtMs == 1_760_649_180_000)

        defaults.set(false, forKey: StartPreferences.stopAtWakeKey)
        #expect(StartPreferences.plan(from: defaults, after: tenPM, timeZone: pacific) == OvernightPlan(wakeAtMs: nil))
    }
}
