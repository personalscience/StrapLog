import StrapLogCore
import SwiftUI

struct RecordingRow: View {
    let summary: RecordingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.name.isEmpty ? "Untitled" : summary.name).font(.headline)
            Text(Formats.summaryLine(summary))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
