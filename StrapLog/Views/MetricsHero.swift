import StrapLogCore
import SwiftUI

/// HR and α1 side by side (stacked at accessibility text sizes), with the latest window's
/// RMSSD, artifacts and α1 age beneath.
struct MetricsHero: View {
    let model: RecorderModel
    let nowMs: Int64
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let alpha1 = model.live.lastAlpha1
        let tiles = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10))
                                                 : AnyLayout(HStackLayout(spacing: 10))
        VStack(alignment: .leading, spacing: 6) {
            tiles {
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
