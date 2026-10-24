import StrapLogCore
import SwiftUI

/// HR and α1 side by side (stacked at accessibility text sizes), with the latest window's
/// RMSSD, artifacts and α1 age beneath. Overnight, the HR tile adds the lowest HR so far.
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
                HeartRateTile(heartRate: model.heartRate, contact: model.contact, overnightLow: overnightLow)
                Alpha1Tile(alpha1: alpha1?.value)
            }
            Text(Formats.heroSubline(rmssd: model.live.latest?.rmssd, artifactRate: model.live.latest?.artifactRate,
                                     alpha1AtMs: alpha1?.atMs, nowMs: nowMs))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("heroSubline")
        }
    }

    private var overnightLow: String? {
        guard let rec = model.activeRecording, model.activePreset.overnight else { return nil }
        return Formats.overnightLow(lowest: model.live.lowestWindow, tzOffsetS: rec.tzOffsetS,
                                    elapsedMs: nowMs - rec.startedAtMs)
    }
}
