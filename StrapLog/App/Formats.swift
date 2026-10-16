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

    /// Seconds since, switching to minutes past a minute: `12 s ago`, `3 min ago`.
    static func ago(ms: Int64) -> String {
        let s = max(0, ms) / 1000
        return s < 60 ? "\(s) s ago" : "\(s / 60) min ago"
    }

    /// The line under the hero tiles: latest window's RMSSD and artifacts, and how old α1 is.
    static func heroSubline(rmssd: Double?, artifactRate: Double?, alpha1AtMs: Int64?, nowMs: Int64) -> String {
        guard let alpha1AtMs else { return "First α1 after 2 min of beats" }
        return "RMSSD \(ms(rmssd)) · artifacts \(percent(artifactRate)) · α1 \(ago(ms: nowMs - alpha1AtMs))"
    }

    /// Toolbar title while recording, e.g. `12:41 · RAVINE`.
    static func recordingTitle(name: String, elapsedMs: Int64) -> String {
        name.isEmpty ? elapsed(ms: elapsedMs) : "\(elapsed(ms: elapsedMs)) · \(name)"
    }

    /// `82 %`, or `--`.
    static func battery(_ percent: Int?) -> String {
        percent.map { "\($0) %" } ?? "--"
    }

    /// The H10's printed ID while connected, or `--`.
    static func deviceId(_ status: LinkStatus) -> String {
        if case .connected(let id) = status { id } else { "--" }
    }

    static func text(_ value: String?) -> String {
        value ?? "--"
    }

    // MARK: Chart

    static func span(_ span: ChartSpan) -> String {
        switch span {
        case .all: "All"
        case .hour: "1 h"
        default: "\(span.rawValue) min"
        }
    }

    static func metric(_ metric: ChartMetric) -> String {
        switch metric {
        case .heartRate: "HR"
        case .alpha1: "α1"
        case .rr: "RR"
        }
    }

    /// Shown over the chart until it has two points to draw.
    static func chartEmpty(_ metric: ChartMetric) -> String {
        metric == .alpha1 ? "α1 after 2 min of beats" : "Waiting for beats…"
    }

    static func axis(_ metric: ChartMetric) -> String {
        switch metric {
        case .heartRate: "bpm"
        case .alpha1: "DFA α1"
        case .rr: "RR ms"
        }
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
