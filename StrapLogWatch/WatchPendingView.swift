import StrapLogCore
import SwiftUI

/// A start or stop on its way to the phone, or the phone's reason it failed.
struct WatchPendingView: View {
    let pending: PendingCommand
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let failure = pending.failure {
                Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
                Text(failure).multilineTextAlignment(.center)
                Button("OK", action: dismiss)
            } else {
                ProgressView()
                Text(pending.waitingText).multilineTextAlignment(.center)
                if pending.queued {
                    Text("Sends when the iPhone is in reach.").font(.footnote).foregroundStyle(.secondary)
                }
                Button("Cancel", role: .cancel, action: dismiss)
            }
        }
        .accessibilityIdentifier("watch.pending")
    }
}
