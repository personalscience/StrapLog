import Foundation

/// How an overnight recording ends on its own, chosen at Start and kept in `recording.context`
/// so a relaunch mid-night still knows it.
public struct OvernightPlan: Codable, Sendable, Equatable {
    /// Stop at this time (epoch ms UTC); nil to rely on getting up.
    public var wakeAtMs: Int64?

    public init(wakeAtMs: Int64?) {
        self.wakeAtMs = wakeAtMs
    }

    /// Default upright time that ends a night: longer than a trip to the bathroom.
    public static let defaultUprightStopMs: Int64 = 10 * 60_000

    /// A plan to stop at the next occurrence of `time`'s hour and minute (a time picker's value).
    public init(wakeAt time: Date, after: Date = .now, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hm = calendar.dateComponents([.hour, .minute], from: time)
        self.init(wakeAtMs: Self.nextWake(hour: hm.hour!, minute: hm.minute!,
                                          afterMs: Int64(after.timeIntervalSince1970 * 1000), timeZone: timeZone))
    }

    /// The first `hour:minute` local time after `afterMs`, e.g. tomorrow's 06:30 from 22:00 tonight.
    /// Takes a time zone, not an offset, so a night across a DST change still wakes on the wall clock.
    public static func nextWake(hour: Int, minute: Int, afterMs: Int64, timeZone: TimeZone) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let after = Date(timeIntervalSince1970: Double(afterMs) / 1000)
        let next = calendar.nextDate(after: after, matching: DateComponents(hour: hour, minute: minute, second: 0),
                                     matchingPolicy: .nextTime)!
        return Int64(next.timeIntervalSince1970 * 1000)
    }

    /// The `recording.context` JSON, e.g. `{"wake_at_ms":1760621400000}`; nil for an empty plan,
    /// keeping `context` NULL when unset.
    public var contextJSON: String? {
        guard self != OvernightPlan(wakeAtMs: nil) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try! encoder.encode(self), as: UTF8.self)
    }

    /// The plan in a `recording.context`; an empty plan when there is none or it does not parse.
    public init(contextJSON: String?) {
        let decoded = contextJSON.flatMap { try? JSONDecoder().decode(Self.self, from: Data($0.utf8)) }
        self = decoded ?? OvernightPlan(wakeAtMs: nil)
    }

    enum CodingKeys: String, CodingKey {
        case wakeAtMs = "wake_at_ms"
    }
}
