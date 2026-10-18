import StrapLogCore
import SwiftUI
import WidgetKit

/// Recording: a heart with the last HR while it is recent, the elapsed time, and the link
/// warning if any, in orange. No word from the phone for long: when it last heard, dimmed.
/// Idle: the app's waveform, dimmed.
struct ComplicationView: View {
    let face: ComplicationFace
    let problem: LinkProblem?
    /// When the shown heart rate arrived.
    let heardAt: Date?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch face {
        case .idle: dimmed(symbol: "waveform.path.ecg", label: "Idle", line: Text("Not recording"))
        case let .recording(status, heartRate): recording(status, heartRate: heartRate, warning: problem != nil)
        case let .noWord(since):
            dimmed(symbol: "waveform.badge.exclamationmark", label: "No word",
                   line: Text("No word since ") + Text(since, style: .time))
        }
    }

    @ViewBuilder
    private func recording(_ status: LiveStatus, heartRate: Int?, warning: Bool) -> some View {
        let tint: Color = warning ? .orange : .red
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: warning ? "exclamationmark.triangle.fill" : "heart.fill")
                    .font(heartRate == nil ? .title2 : nil)
                    .foregroundStyle(tint)
                if let heartRate {
                    Text("\(heartRate)").font(.system(.title3, design: .rounded).monospacedDigit())
                }
            }
            .widgetAccentable()
        case .accessoryCorner:
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(tint)
                .widgetLabel { Text(status.startedAt, style: .timer).monospacedDigit() }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Label(ActivityPreset.named(status.activity).title, systemImage: "record.circle")
                    .foregroundStyle(tint)
                    .widgetAccentable()
                Text(status.startedAt, style: .timer).font(.headline.monospacedDigit())
                if warning {
                    Text(status.linkText).foregroundStyle(.orange)
                } else if let heartRate, let heardAt {
                    Text("♥ \(heartRate) at ") + Text(heardAt, style: .time)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            if let heartRate {
                Text("♥ \(heartRate) · ") + Text(status.startedAt, style: .timer)
            } else {
                Text("♥ ") + Text(status.startedAt, style: .timer)
            }
        }
    }

    /// `symbol` dimmed, for idle and for no word: `label` in the corner, `line` under the name.
    @ViewBuilder
    private func dimmed(symbol: String, label: String, line: Text) -> some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: symbol).font(.title2).foregroundStyle(.secondary)
        case .accessoryCorner:
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
                .widgetLabel(label)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("StrapLog", systemImage: symbol)
                line.foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text("StrapLog · ") + line
        }
    }
}
