import StrapLogCore
import WidgetKit

/// One timeline entry: the saved snapshot, nil before the Watch app has heard from the phone.
struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot?

    var face: ComplicationFace { snapshot?.face(at: date) ?? .idle }
}
