import Foundation

/// The Start screen's remembered choices, in `UserDefaults`. Shortcuts read the same keys, so
/// a "Start Sleep" automation stops at the wake time set on the Start screen.
public enum StartPreferences {
    public static let activityKey = "activity"
    public static let stopAtWakeKey = "stopAtWake"
    /// Reference-date seconds; only its hour and minute matter (`OvernightPlan(wakeAt:)`).
    public static let wakeAtKey = "wakeAt"

    public static let defaultStopAtWake = true
    /// 06:30 local, as reference-date seconds.
    public static var defaultWakeAt: TimeInterval {
        Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now)!.timeIntervalSinceReferenceDate
    }

    /// The plan for an overnight Start: the next `wakeAt` if `stopAtWake`, else none.
    public static func plan(stopAtWake: Bool, wakeAt: TimeInterval, after: Date = .now,
                            timeZone: TimeZone = .current) -> OvernightPlan {
        guard stopAtWake else { return OvernightPlan(wakeAtMs: nil) }
        return OvernightPlan(wakeAt: Date(timeIntervalSinceReferenceDate: wakeAt), after: after, timeZone: timeZone)
    }

    /// The plan from saved choices, with the Start screen's defaults for unset keys.
    public static func plan(from defaults: UserDefaults, after: Date = .now,
                            timeZone: TimeZone = .current) -> OvernightPlan {
        plan(stopAtWake: defaults.object(forKey: stopAtWakeKey) as? Bool ?? defaultStopAtWake,
             wakeAt: defaults.object(forKey: wakeAtKey) as? TimeInterval ?? defaultWakeAt,
             after: after, timeZone: timeZone)
    }
}
