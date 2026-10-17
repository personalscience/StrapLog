import Foundation

/// What the Live Activity (Lock Screen, Dynamic Island, StandBy, Watch Smart Stack) shows
/// about the open recording. Built in one place, `RecorderModel.liveStatus`; the app sends it
/// as the activity's `ContentState`, so it stays small and `Codable`.
public struct LiveStatus: Sendable, Codable, Hashable {
    public let name: String
    /// `ActivityPreset.id`.
    public let activity: String
    public let startedAtMs: Int64
    public let heartRate: Int?
    public let contact: Bool?
    /// Whether the strap is connected.
    public let linked: Bool
    /// Latest window's DFA α1 and RMSSD (ms), nil until the first window closes.
    public let alpha1: Double?
    public let rmssd: Double?
    public let battery: Int?
    /// The activity's marker bar, offered as buttons.
    public let markers: [String]
    public let markerCount: Int
    /// The latest marker, so a tap on the Live Activity shows that it took.
    public let lastMarkerLabel: String?
    public let lastMarkerText: String?
    public let lastMarkerAtMs: Int64?

    /// After this long without an update the activity is marked stale, so a dead app or link
    /// shows as a warning instead of an old HR that looks live.
    public static let staleAfterMs: Int64 = 60_000

    public init(name: String, activity: String, startedAtMs: Int64, heartRate: Int?, contact: Bool?,
                linked: Bool, alpha1: Double?, rmssd: Double?, battery: Int?, markers: [String], markerCount: Int,
                lastMarkerLabel: String? = nil, lastMarkerText: String? = nil, lastMarkerAtMs: Int64? = nil) {
        self.name = name
        self.activity = activity
        self.startedAtMs = startedAtMs
        self.heartRate = heartRate
        self.contact = contact
        self.linked = linked
        self.alpha1 = alpha1
        self.rmssd = rmssd
        self.battery = battery
        self.markers = markers
        self.markerCount = markerCount
        self.lastMarkerLabel = lastMarkerLabel
        self.lastMarkerText = lastMarkerText
        self.lastMarkerAtMs = lastMarkerAtMs
    }

    public var alpha1Band: Alpha1Band? { alpha1.map(Alpha1Band.init(alpha1:)) }
    public var startedAt: Date { Date(timeIntervalSince1970: Double(startedAtMs) / 1000) }
    public var lastMarkerAt: Date? { lastMarkerAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) } }

    /// Whether `label`'s button made the latest marker, so it can be shown pressed.
    public func isLastMarker(_ label: String) -> Bool { lastMarkerLabel == label }

    // MARK: Display strings (the widget extension has no `Formats`)

    public var heartRateText: String { heartRate.map(String.init) ?? "--" }
    public var alpha1Text: String { alpha1.map { String(format: "%.2f", $0) } ?? "--" }
    public var rmssdText: String { rmssd.map { String(format: "%.0f ms", $0) } ?? "--" }

    /// One short line on the link, e.g. `H10 · 82 %`, `No skin contact`, `Reconnecting…`.
    public var linkText: String {
        guard linked else { return "Reconnecting…" }
        if contact == false { return "No skin contact" }
        return battery.map { "H10 · \($0) %" } ?? "H10"
    }

    /// The footer line: `linkText`, or a warning once the activity is stale (no update for
    /// `staleAfterMs`: the app or the link is gone).
    public func footer(isStale: Bool) -> String {
        isStale ? "No update for over a minute — open StrapLog" : linkText
    }

    /// `Marked awake ·`, followed in the view by a live relative time; nil before the first marker.
    public var markedText: String? {
        lastMarkerText.map { "Marked \(Self.markerTitle($0)) ·" }
    }

    /// Whether the footer is a warning.
    public func needsAttention(isStale: Bool) -> Bool {
        isStale || !linked || contact == false
    }

    /// A marker label as a button title: `lights_out` → `lights out`.
    public static func markerTitle(_ label: String) -> String {
        label.replacingOccurrences(of: "_", with: " ")
    }
}
