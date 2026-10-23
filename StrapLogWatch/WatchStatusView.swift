import StrapLogCore
import SwiftUI

/// The recording at a glance with its marker and stop buttons, a start or stop on its way, or
/// the start buttons. Re-evaluated every few seconds so a phone that went quiet shows as stale
/// rather than as an old HR that looks live. While the phone is gone, HR comes from the
/// strap's broadcasts (`StrapHeart`), labelled as such. With the wrist down (Always On) the
/// recording shrinks to `WatchDimmedView` and the timeline slows to once a minute.
struct WatchStatusView: View {
    let phone: PhoneLink
    let heart: StrapHeart
    @State private var confirmingStop = false
    @Environment(\.isLuminanceReduced) private var isDimmed

    var body: some View {
        TimelineView(.periodic(from: .now, by: isDimmed ? 60 : 5)) { timeline in
            let strap = heart.source == .strap ? heart.shownReading(at: timeline.date) : nil
            if let pending = phone.pending {
                WatchPendingView(pending: pending) { phone.dismissPending() }
            } else if let status = phone.status, isDimmed {
                WatchDimmedView(status: status, isStale: phone.isStale(at: timeline.date),
                                heartRateText: heartRateText(status, strap: strap))
            } else if let status = phone.status {
                ScrollView {
                    VStack(spacing: 8) {
                        recording(status, isStale: phone.isStale(at: timeline.date), strap: strap)
                        markers(status)
                        stop
                    }
                }
            } else {
                WatchStartView(phone: phone, showsStrap: heart.source == .strap, strap: strap)
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

    /// `strap` is the strap's reading while it stands in for the phone's HR.
    private func recording(_ status: LiveStatus, isStale: Bool, strap: StrapBroadcast?) -> some View {
        VStack(spacing: 4) {
            Text(status.startedAt, style: .timer)
                .font(.headline.monospacedDigit())
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text(heartRateText(status, strap: strap))
                    .font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
            }
            if heart.source == .strap {
                Text(StrapBroadcast.caption(for: strap)).font(.footnote).foregroundStyle(.secondary)
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

    private func heartRateText(_ status: LiveStatus, strap: StrapBroadcast?) -> String {
        heart.source == .strap ? strap?.heartRateText ?? "--" : status.heartRateText
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
