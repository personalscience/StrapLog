import StrapLogCore
import SwiftUI
import WidgetKit

/// Recording: a heart with the last HR, the elapsed time, and the link warning if any, in
/// orange. Idle: the app's waveform, dimmed.
struct ComplicationView: View {
    let snapshot: ComplicationSnapshot?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let status = snapshot?.status {
            recording(status, warning: snapshot?.problem != nil)
        } else {
            idle
        }
    }

    @ViewBuilder
    private func recording(_ status: LiveStatus, warning: Bool) -> some View {
        let tint: Color = warning ? .orange : .red
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: warning ? "exclamationmark.triangle.fill" : "heart.fill").foregroundStyle(tint)
                Text(status.heartRateText).font(.system(.title3, design: .rounded).monospacedDigit())
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
                } else if let receivedAt = snapshot?.receivedAt {
                    Text("♥ \(status.heartRateText) at ") + Text(receivedAt, style: .time)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text("♥ \(status.heartRateText) · ") + Text(status.startedAt, style: .timer)
        }
    }

    @ViewBuilder
    private var idle: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "waveform.path.ecg").font(.title2).foregroundStyle(.secondary)
        case .accessoryCorner:
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(.secondary)
                .widgetLabel("Idle")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("StrapLog", systemImage: "waveform.path.ecg")
                Text("Not recording").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text("StrapLog idle")
        }
    }
}
