import Foundation
import Testing
@testable import StrapLogCore

@Suite("OvernightPlan")
struct OvernightPlanTests {
    let pacific = TimeZone(identifier: "America/Los_Angeles")!
    /// 2025-10-15 22:00 PDT = 2025-10-16 05:00 UTC.
    let tenPM: Int64 = 1_760_590_800_000

    @Test("next wake is tomorrow from the evening and today from the small hours, in local time")
    func nextWake() {
        // 06:30 PDT on 2025-10-16 = 13:30 UTC.
        let wake: Int64 = 1_760_621_400_000
        #expect(OvernightPlan.nextWake(hour: 6, minute: 30, afterMs: tenPM, timeZone: pacific) == wake)
        #expect(OvernightPlan.nextWake(hour: 6, minute: 30, afterMs: wake - 3 * 3_600_000, timeZone: pacific) == wake)
        #expect(OvernightPlan.nextWake(hour: 6, minute: 30, afterMs: wake, timeZone: pacific) == wake + 86_400_000)
    }

    @Test("a picker's time on any day means its next occurrence")
    func pickerTime() {
        // A picker value from another day and DST state: 2023-11-14 14:13 PST.
        let picked = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = OvernightPlan(wakeAt: picked, after: Date(timeIntervalSince1970: Double(tenPM) / 1000),
                                 timeZone: pacific)
        // Next 14:13 PDT after 2025-10-15 22:00 PDT is 2025-10-16 14:13 PDT = 21:13 UTC.
        #expect(plan.wakeAtMs == 1_760_649_180_000)
    }

    @Test("the night DST ends still wakes at 06:30 on the wall clock")
    func dst() {
        // 2026-10-31 22:00 PDT = Nov 1 05:00 UTC; clocks fall back at 02:00, so 06:30 PST = 14:30 UTC.
        let halloween: Int64 = 1_793_509_200_000
        #expect(OvernightPlan.nextWake(hour: 6, minute: 30, afterMs: halloween, timeZone: pacific) == 1_793_543_400_000)
    }

    @Test("round-trips through recording.context; missing or foreign context is an empty plan")
    func context() {
        let plan = OvernightPlan(wakeAtMs: 1_760_621_400_000)
        #expect(plan.contextJSON == #"{"wake_at_ms":1760621400000}"#)
        #expect(OvernightPlan(contextJSON: plan.contextJSON) == plan)
        #expect(OvernightPlan(wakeAtMs: nil).contextJSON == nil)
        #expect(OvernightPlan(contextJSON: nil) == OvernightPlan(wakeAtMs: nil))
        #expect(OvernightPlan(contextJSON: "not json") == OvernightPlan(wakeAtMs: nil))
    }
}
