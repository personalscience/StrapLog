import StrapLogCore
import SwiftUI

/// StandBy's full-screen Live Activity: a nightstand glance from across the room. StandBy lays
/// the view out at Lock Screen size (about 160 pt tall) and scales it up, so sizes here are
/// Lock Screen points and there is no room for the marker buttons. Night Mode tints it red.
struct StandByStatusView: View {
    let status: LiveStatus
    let isStale: Bool

    var body: some View {
        VStack(spacing: 2) {
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
            .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                LiveMetricLabel(value: status.heartRateText, caption: "bpm",
                                color: isStale ? .secondary : nil, size: 56)
                Spacer(minLength: 8)
                LiveMetricLabel(value: status.alpha1Text, caption: "DFA α1", color: status.alpha1Band?.color, size: 56)
                Spacer(minLength: 8)
                LiveMetricLabel(value: status.rmssdText, caption: "RMSSD", size: 34)
            }
            Text(status.footer(isStale: isStale))
                .font(.caption)
                .foregroundStyle(status.needsAttention(isStale: isStale) ? .orange : .secondary)
            LiveMarkedLine(status: status)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
