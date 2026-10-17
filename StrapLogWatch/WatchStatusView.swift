import StrapLogCore
import SwiftUI

/// The recording at a glance, or "Not recording". Re-evaluated every few seconds so a phone
/// that went quiet shows as stale rather than as an old HR that looks live.
struct WatchStatusView: View {
    let phone: PhoneLink

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            if let status = phone.status {
                recording(status, isStale: phone.isStale(at: timeline.date))
            } else {
                ContentUnavailableView("Not recording", systemImage: "heart.slash",
                                       description: Text("Start a recording on the iPhone."))
            }
        }
    }

    private func recording(_ status: LiveStatus, isStale: Bool) -> some View {
        VStack(spacing: 4) {
            Text(status.startedAt, style: .timer)
                .font(.headline.monospacedDigit())
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text(status.heartRateText)
                    .font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
            }
            HStack(spacing: 6) {
                Circle().fill(status.alpha1Band?.color ?? .secondary).frame(width: 10, height: 10)
                Text("α1 \(status.alpha1Text)").font(.body.monospacedDigit())
            }
            Text(status.footer(isStale: isStale))
                .font(.footnote)
                .foregroundStyle(status.needsAttention(isStale: isStale) ? .orange : .secondary)
        }
        .accessibilityIdentifier("watch.status")
    }
}
