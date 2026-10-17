import StrapLogCore
import SwiftUI

/// Confirms the latest marker, e.g. `Marked awake · 12 sec ago`; the time ticks on its own.
struct LiveMarkedLine: View {
    let status: LiveStatus

    var body: some View {
        if let text = status.markedText, let at = status.lastMarkerAt {
            (Text(Image(systemName: "checkmark.circle.fill")) + Text(" \(text) ")
                + Text(at, style: .relative) + Text(" ago"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.green)
                .lineLimit(1)
        }
    }
}
