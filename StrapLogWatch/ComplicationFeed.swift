import Foundation
import StrapLogCore
import WidgetKit

/// Hands the phone's statuses to the complication: saves the ones worth a reload
/// (`ComplicationSnapshot.replaces`) for the widget extension and reloads its timelines.
@MainActor
final class ComplicationFeed {
    private let store = ComplicationStore.shared
    private lazy var shown = store.load()

    func show(_ status: LiveStatus?, receivedAt: Date) {
        let next = ComplicationSnapshot(status: status, receivedAtMs: Int64(receivedAt.timeIntervalSince1970 * 1000))
        guard next.replaces(shown) else { return }
        store.save(next)
        shown = next
        WidgetCenter.shared.reloadTimelines(ofKind: ComplicationStore.widgetKind)
    }
}
