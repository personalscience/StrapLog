import StrapLogCore
import SwiftUI
import WidgetKit

/// The open recording's Live Activity. The Lock Screen view is also what StandBy shows full
/// screen; the `.small` family is the Watch Smart Stack.
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveRecordingAttributes.self) { context in
            LiveStatusView(status: context.state, isStale: context.isStale)
        } dynamicIsland: { context in
            let status = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveMetricLabel(value: status.heartRateText, caption: "bpm")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveMetricLabel(value: status.alpha1Text, caption: "α1", color: status.alpha1Band?.color)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(status.name).font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        LiveControls(status: status)
                        LiveMarkedLine(status: status)
                    }
                }
            } compactLeading: {
                Label(status.heartRateText, systemImage: "heart.fill")
                    .foregroundStyle(status.linked ? .red : .secondary)
            } compactTrailing: {
                Text(status.alpha1Text).foregroundStyle(status.alpha1Band?.color ?? .secondary)
            } minimal: {
                Text(status.heartRateText).foregroundStyle(status.linked ? .red : .secondary)
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}
