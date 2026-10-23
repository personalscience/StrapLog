import Foundation

/// What a recording is of, and how the app records it. Each preset is a value: adding an
/// activity means adding one here, not a new screen. Stored as `recording.activity = id`.
public struct ActivityPreset: Sendable, Equatable, Hashable, Identifiable, Encodable {
    /// Stored in `recording.activity`; never rename one that has shipped.
    public let id: String
    public let title: String
    /// SF Symbol for pickers and rows.
    public let systemImage: String
    /// One-tap marker labels, in bar order, stored in `event.label`.
    public let markers: [String]
    /// Overnight mode: posture events, auto-stop (`OvernightPlan`), and the live lowest HR on the HR tile.
    public let overnight: Bool

    /// What an export says about its preset (`ExportMeta`); the symbol is app chrome only.
    enum CodingKeys: String, CodingKey {
        case id, title, markers, overnight
    }

    public static let sleep = ActivityPreset(id: "sleep", title: "Sleep", systemImage: "bed.double",
                                             markers: ["lights_out", "awake", "up"], overnight: true)
    public static let other = ActivityPreset(id: "other", title: "Other", systemImage: "waveform.path.ecg",
                                             markers: ["a", "b", "c", "end"], overnight: false)

    /// Picker order.
    public static let all = [sleep, other]

    /// The preset stored as `id`; `other` for an id this build does not know.
    public static func named(_ id: String) -> ActivityPreset {
        all.first { $0.id == id } ?? other
    }

    /// This preset with another marker bar (`MarkerPresets`).
    public func with(markers: [String]) -> ActivityPreset {
        ActivityPreset(id: id, title: title, systemImage: systemImage, markers: markers, overnight: overnight)
    }

    /// The name a recording gets when none is typed: `<id> <local date>`, e.g. `sleep 2026-10-16`.
    public func defaultName(atMs: Int64, tzOffsetS: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: tzOffsetS)
        f.dateFormat = "yyyy-MM-dd"
        return "\(id) \(f.string(from: Date(timeIntervalSince1970: Double(atMs) / 1000)))"
    }
}
