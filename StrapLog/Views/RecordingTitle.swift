import StrapLogCore
import SwiftUI

/// Toolbar centre: a red recording dot, elapsed time and the session name; `StrapLog` when idle.
struct RecordingTitle: View {
    let recording: Recording?

    var body: some View {
        if let recording {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text(Formats.recordingTitle(name: recording.name, elapsedMs: nowMs - recording.startedAtMs))
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("recordingTitle")
            }
        } else {
            Text("StrapLog").font(.headline)
        }
    }
}
