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

    /// Confirms the latest marker tap, e.g. `b · 12 s ago · 5 markers`.
    static func marker(_ last: RecordingEvent?, count: Int, nowMs: Int64) -> String {
        guard let last else { return "No markers yet" }
        let ago = max(0, nowMs - last.atMs) / 1000
        return "\(last.note ?? "") · \(ago) s ago · \(count) marker\(count == 1 ? "" : "s")"
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

    // MARK: Live metrics

    /// Two decimals (α1, LnRMSSD), or `--`.
    static func decimal(_ v: Double?) -> String {
        v.map { String(format: "%.2f", $0) } ?? "--"
    }

    /// `42.1 ms`, or `--`.
    static func ms(_ v: Double?) -> String {
        v.map { String(format: "%.1f ms", $0) } ?? "--"
    }

    /// `61 bpm`, or `--`.
    static func bpm(_ v: Double?) -> String {
        v.map { String(format: "%.0f bpm", $0) } ?? "--"
    }

    /// A fraction as `1.2 %`, or `--`.
    static func percent(_ fraction: Double?) -> String {
        fraction.map { String(format: "%.1f %%", $0 * 100) } ?? "--"
    }

    /// Where the latest 2-minute window stands.
    static func window(endMs: Int64?, hasFeatures: Bool, nowMs: Int64) -> String {
        guard let endMs else { return "First values after 2 min of beats" }
        let ago = "\(max(0, nowMs - endMs) / 1000) s ago"
        return hasFeatures ? "2-min window ending \(ago)" : "Too few beats in the window ending \(ago)"
    }

    static func contact(_ contact: Bool) -> String {
        contact ? "Skin contact" : "No skin contact"
    }

    // MARK: Pacer

    static func rate(_ breathsPerMinute: Double) -> String {
        String(format: "%.1f breaths / min", breathsPerMinute)
    }

    /// Whole seconds left in this half-breath, rounded up so it never shows 0 while running.
    static func countdown(seconds: Double) -> String {
        String(Int(seconds.rounded(.up)))
    }
}
