import StrapLogCore
import SwiftUI

/// End-of-session numbers in a grid, then minutes per α1 band. Home's last-recording card and
/// the top of the detail screen.
struct SessionSummaryCard: View {
    let summary: SessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    stat("Duration", Formats.duration(ms: summary.durationMs), id: "summaryDuration")
                    stat("Mean HR", Formats.bpm(summary.meanHR), id: "summaryHR")
                    stat("Lowest HR", Formats.bpm(summary.lowestHR), id: "summaryLowestHR")
                    stat("Beats", "\(summary.beats)", id: "summaryBeats")
                }
                GridRow {
                    stat("RMSSD", Formats.ms(summary.rmssd), id: "summaryRMSSD")
                    stat("Artifacts", Formats.percent(summary.artifactRate), id: "summaryArtifacts")
                    stat("Coverage", Formats.percent(summary.coverage), id: "summaryCoverage")
                }
            }
            Alpha1MinutesBar(minutes: summary.alpha1Minutes)
        }
        .padding(.vertical, 4)
    }

    private func stat(_ title: String, _ value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).accessibilityIdentifier(id)
        }
        .accessibilityElement(children: .combine)
    }
}
