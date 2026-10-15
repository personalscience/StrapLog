import StrapLogCore
import SwiftUI

struct RecordingRow: View {
    let summary: RecordingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.name.isEmpty ? "Untitled" : summary.name).font(.headline)
            Text("\(Formats.started(summary)) · \(Formats.duration(summary)) · \(summary.beatCount) beats")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
