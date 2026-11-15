import StrapLogCore
import SwiftUI

/// Heart follows breath: the trace, the swing and sync, and the per-breath bars, under the
/// running pacer while `RecorderModel.rsaShown`.
struct RSAPanel: View {
    let reading: RSAReading?
    let pacer: BreathingPacer
    let connected: Bool

    var body: some View {
        VStack(spacing: 10) {
            if let reading {
                RSATraceView(reading: reading, pacer: pacer)
                RSASwingView(reading: reading, pacer: pacer)
                RSABreathBars(breaths: reading.breaths, topBpm: reading.barTopBpm)
            }
            if let waiting = Formats.rsaWaiting(reading, connected: connected, device: AppBrand.current.device) {
                Text(waiting)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("rsaWaiting")
            }
        }
    }
}
