import StrapLogCore
import SwiftUI

/// HR and α1 side by side, with the latest window's RMSSD, artifacts and α1 age beneath.
struct MetricsHero: View {
    let model: RecorderModel
    let nowMs: Int64

    var body: some View {
        let alpha1 = model.live.lastAlpha1
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                HeartRateTile(heartRate: model.heartRate, contact: model.contact)
                Alpha1Tile(alpha1: alpha1?.value)
            }
            Text(Formats.heroSubline(rmssd: model.live.latest?.rmssd, artifactRate: model.live.latest?.artifactRate,
                                     alpha1AtMs: alpha1?.atMs, nowMs: nowMs))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("heroSubline")
        }
    }
}
