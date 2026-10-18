import StrapLogCore
import SwiftUI
import WidgetKit

/// Recording: a heart with the last HR while it is recent, the elapsed time, and the link
/// warning if any, in orange. No word from the phone for long: when it last heard, dimmed.
/// Idle: the app's strap mark, dimmed.
struct ComplicationView: View {
    let face: ComplicationFace
    let problem: LinkProblem?
    /// When the shown heart rate arrived.
    let heardAt: Date?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch face {
        case .idle: dimmed(.strap, label: "Idle", line: Text("Not recording"))
        case let .recording(status, heartRate): recording(status, heartRate: heartRate, warning: problem != nil)
        case let .noWord(since):
            dimmed(.symbol("waveform.badge.exclamationmark"), label: "No word",
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

    /// `glyph` dimmed, for idle and for no word: `label` in the corner, `line` under the name.
    @ViewBuilder
    private func dimmed(_ glyph: DimmedGlyph, label: String, line: Text) -> some View {
        switch family {
        case .accessoryCircular:
            image(glyph, width: 40).foregroundStyle(.secondary)
        case .accessoryCorner:
            image(glyph, width: 32)
                .foregroundStyle(.secondary)
                .widgetLabel(label)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label { Text("StrapLog") } icon: { image(glyph, width: 28) }
                line.foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text("StrapLog · ") + line
        }
    }

    /// The strap mark is a wide vector, so it is sized by width; symbols size by font as before.
    @ViewBuilder
    private func image(_ glyph: DimmedGlyph, width: CGFloat) -> some View {
        switch glyph {
        case .strap:
            Image("StrapMark").resizable().scaledToFit().frame(width: width)
        case .symbol(let name):
            if family == .accessoryRectangular {
                Image(systemName: name)
            } else {
                Image(systemName: name).font(.title2)
            }
        }
    }
}
