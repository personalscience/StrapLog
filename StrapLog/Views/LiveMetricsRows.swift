import StrapLogCore
import SwiftUI

/// The latest 2-minute window: window HR, RMSSD, LnRMSSD, α1 in its colour band, artifact %.
struct LiveMetricsRows: View {
    let live: LiveMetrics
    let nowMs: Int64

    var body: some View {
        let w = live.latest
        Text(Formats.window(endMs: live.latestWindowEndMs, hasFeatures: w != nil, nowMs: nowMs))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("windowStatus")
        LabeledContent("DFA α1") {
            HStack {
                Text(Formats.decimal(w?.alpha1))
                    .font(.title2.bold().monospacedDigit())
                if let a = w?.alpha1 {
                    let band = Alpha1Band(alpha1: a)
                    Text(band.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(band.color.opacity(0.2), in: Capsule())
                        .foregroundStyle(band.color)
                }
            }
        }
        .accessibilityIdentifier("alpha1")
        LabeledContent("RMSSD", value: Formats.ms(w?.rmssd))
            .accessibilityIdentifier("rmssd")
        LabeledContent("LnRMSSD", value: Formats.decimal(w?.lnRMSSD))
        LabeledContent("Window HR", value: Formats.bpm(w?.hrBpm))
        LabeledContent("Artifacts", value: Formats.percent(w?.artifactRate))
    }
}
