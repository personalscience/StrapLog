import StrapLogCore
import SwiftUI

/// The recording with the wrist down (Always On): heart rate, a heart or an orange warning,
/// and the marker count. No buttons; the system dims it further. Its timeline ticks once a
/// minute, so the heart rate is up to a minute old until the wrist comes up.
struct WatchDimmedView: View {
    let status: LiveStatus
    let isStale: Bool
    /// The strap's reading while it stands in for the phone's HR.
    let heartRateText: String

    var body: some View {
        let warning = status.needsAttention(isStale: isStale)
        VStack(spacing: 6) {
            Image(systemName: warning ? "exclamationmark.triangle.fill" : "heart.fill")
                .font(.title2)
                .foregroundStyle(warning ? .orange : .red)
            Text(heartRateText)
                .font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
            Label("\(status.markerCount)", systemImage: "flag.fill")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("watch.dimmed")
    }
}
