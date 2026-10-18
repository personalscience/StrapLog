import StrapLogCore
import WidgetKit

/// The `ComplicationStore` snapshot now and again at each `faceChanges(after:)`, so a face the
/// Watch app stops reloading drops the heart rate, then the recording. The elapsed time ticks
/// on its own.
struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: .now, snapshot: ComplicationStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let snapshot = ComplicationStore.shared.load()
        let now = Date.now
        let dates = [now] + (snapshot?.faceChanges(after: now) ?? [])
        let entries = dates.map { ComplicationEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .never))
    }
}
