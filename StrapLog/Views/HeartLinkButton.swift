import StrapLogCore
import SwiftUI

/// The strap link at a glance: a glowing red heart when connected, grey and pulsing while
/// searching, orange and struck through when lost. Tap for the device sheet.
struct HeartLinkButton: View {
    let link: LinkStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: link.heartSymbol)
                .foregroundStyle(link.heartColor)
                .shadow(color: link.isConnected ? .red.opacity(0.7) : .clear, radius: 6)
                .symbolEffect(.pulse, isActive: link == .searching)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(Formats.link(link))
        .accessibilityIdentifier("heartLink")
    }
}
