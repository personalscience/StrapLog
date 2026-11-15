import StrapLogCore
import SwiftUI

/// One pacer run on the recording detail screen: its rate and length, then how far heart rate
/// followed the breath across it (`RSASummary`).
struct RSARunRow: View {
    let summary: RSASummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Formats.rsaRunTitle(summary)).font(.subheadline.bold())
            Text(Formats.rsaRunResult(summary)).font(.footnote.monospacedDigit())
            if let peak = Formats.rsaRunPeak(summary) {
                Text(peak).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
