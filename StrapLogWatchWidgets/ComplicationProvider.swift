import StrapLogCore
import WidgetKit

/// A single entry from `ComplicationStore`; the elapsed time ticks on its own, and only the
/// Watch app's reloads change the rest.
struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: .now, snapshot: ComplicationStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [ComplicationEntry(date: .now, snapshot: ComplicationStore.shared.load())],
                            policy: .never))
    }
}
