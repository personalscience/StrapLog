import Foundation
import StrapLogCore

/// Display strings, kept out of the views so they can be unit-tested.
enum Formats {
    /// `H:MM:SS`, or `M:SS` under an hour.
    static func elapsed(ms: Int64) -> String {
        let s = max(0, ms / 1000)
        let (h, m, sec) = (s / 3600, (s % 3600) / 60, s % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// Seconds with one decimal, e.g. `4.0 s`.
    static func gap(ms: Int64) -> String {
        String(format: "%.1f s", Double(ms) / 1000)
    }

    static func link(_ status: LinkStatus) -> String {
        switch status {
        case .searching: "Searching for H10…"
        case .connected(let id): "H10 \(id)"
        case .disconnected: "Disconnected — reconnecting"
        case .bluetoothOff: "Bluetooth is off"
        }
    }

    /// Start time in the recording's own time zone, e.g. `Oct 14, 21:05`.
    static func started(_ summary: RecordingSummary) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: summary.tzOffsetS)
        f.dateFormat = "MMM d, HH:mm"
        return f.string(from: Date(timeIntervalSince1970: Double(summary.startedAtMs) / 1000))
    }

    static func duration(_ summary: RecordingSummary) -> String {
        guard let end = summary.endedAtMs else { return "open" }
        return elapsed(ms: end - summary.startedAtMs)
    }
}
