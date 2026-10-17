@testable import StrapLogCore

/// A `LiveStatusDisplay` that keeps every value shown.
@MainActor
final class RecordingDisplay: LiveStatusDisplay {
    private(set) var shown: [LiveStatus?] = []
    func show(_ status: LiveStatus?) { shown.append(status) }
}
