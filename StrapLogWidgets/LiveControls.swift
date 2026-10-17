import AppIntents
import StrapLogCore
import SwiftUI

/// The activity's first marker buttons and Stop. Taps run in the app (`LiveActivityIntent`);
/// the button that made the latest marker is tinted green.
struct LiveControls: View {
    let status: LiveStatus
    static let markerLimit = 3

    var body: some View {
        HStack(spacing: 6) {
            ForEach(status.markers.prefix(Self.markerLimit), id: \.self) { label in
                Button(intent: MarkFromLiveActivityIntent(label: label)) {
                    Text(LiveStatus.markerTitle(label)).lineLimit(1).frame(maxWidth: .infinity)
                }
                .tint(status.isLastMarker(label) ? .green : nil)
            }
            Button(intent: StopFromLiveActivityIntent()) {
                Image(systemName: "stop.fill").accessibilityLabel("Stop")
            }
            .tint(.red)
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }
}
