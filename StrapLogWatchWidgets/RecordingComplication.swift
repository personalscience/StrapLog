import StrapLogCore
import SwiftUI
import WidgetKit

/// The Watch face's recording indicator; a tap opens the Watch app. The Watch app reloads it
/// when a recording starts or stops, its link changes, or the HR shown grows old.
struct RecordingComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ComplicationStore.widgetKind, provider: ComplicationProvider()) { entry in
            ComplicationView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("StrapLog")
        .description("Whether the iPhone is recording, for how long, and the last heart rate.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
