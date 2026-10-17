import StrapLogCore
import SwiftUI
import WidgetKit

/// Lock Screen and StandBy (`.medium`), or the Watch Smart Stack (`.small`).
struct LiveStatusView: View {
    let status: LiveStatus
    let isStale: Bool
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small: small
        default: medium
        }
    }

    private var small: some View {
        HStack {
            LiveMetricLabel(value: status.heartRateText, caption: "bpm", color: isStale ? .secondary : nil, size: 28)
            LiveMetricLabel(value: status.alpha1Text, caption: "α1", color: status.alpha1Band?.color, size: 28)
        }
        .padding(6)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(status.name, systemImage: ActivityPreset.named(status.activity).systemImage)
                    .lineLimit(1)
                Spacer()
                Text(timerInterval: status.startedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90, alignment: .trailing)
            }
            .font(.footnote)
            HStack {
                LiveMetricLabel(value: status.heartRateText, caption: "bpm", color: isStale ? .secondary : nil, size: 44)
                Spacer()
                LiveMetricLabel(value: status.alpha1Text, caption: "DFA α1", color: status.alpha1Band?.color, size: 44)
                Spacer()
                LiveMetricLabel(value: status.rmssdText, caption: "RMSSD", size: 28)
            }
            Text(status.footer(isStale: isStale))
                .font(.caption)
                .foregroundStyle(status.needsAttention(isStale: isStale) ? .orange : .secondary)
            LiveMarkedLine(status: status)
            LiveControls(status: status)
        }
        .padding()
    }
}
