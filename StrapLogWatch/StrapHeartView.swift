import StrapLogCore
import SwiftUI

/// The strap's broadcast HR while the phone is gone, with where it comes from.
struct StrapHeartView: View {
    let reading: StrapBroadcast?

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text(reading?.heartRateText ?? "--")
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
            }
            Text(StrapBroadcast.caption(for: reading)).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("watch.strapHeart")
    }
}
