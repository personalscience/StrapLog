import StrapLogCore
import SwiftUI

/// The recording at a glance with its marker and stop buttons, a start or stop on its way, or
/// the start buttons. Re-evaluated every few seconds so a phone that went quiet shows as stale
/// rather than as an old HR that looks live.
struct WatchStatusView: View {
    let phone: PhoneLink
    @State private var confirmingStop = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            if let pending = phone.pending {
                WatchPendingView(pending: pending) { phone.dismissPending() }
            } else if let status = phone.status {
                ScrollView {
                    VStack(spacing: 8) {
                        recording(status, isStale: phone.isStale(at: timeline.date))
                        markers(status)
                        stop
                    }
                }
            } else {
                WatchStartView(phone: phone)
            }
        }
    }

    /// Confirmed, because a stray tap would end the night.
    private var stop: some View {
        Button(role: .destructive) {
            confirmingStop = true
        } label: {
            Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("watch.stop")
        .confirmationDialog("Stop recording?", isPresented: $confirmingStop) {
            Button("Stop Recording", role: .destructive) {
                Task { await phone.request(.stop) }
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

    /// The big button marks the next label; the rest of the bar follows for a repeat (`awake`).
    @ViewBuilder
    private func markers(_ status: LiveStatus) -> some View {
        if let next = status.nextMarker {
            Button {
                Task { await phone.send(.markNext) }
            } label: {
                Label("Mark \(LiveStatus.markerTitle(next))", systemImage: "flag.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .tint(.green)
            .accessibilityIdentifier("watch.markNext")
        }
        LiveMarkedLine(status: status)
        ForEach(status.markers, id: \.self) { label in
            Button(LiveStatus.markerTitle(label)) {
                Task { await phone.send(.mark(label)) }
            }
            .tint(status.isLastMarker(label) ? .green : nil)
        }
    }
}
