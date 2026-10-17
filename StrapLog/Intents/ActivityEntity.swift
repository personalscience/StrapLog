import AppIntents
import StrapLogCore

/// An `ActivityPreset` as Shortcuts sees it. An entity, not an `AppEnum`, so a new preset
/// shows up in Shortcuts without touching this file.
struct ActivityEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static let defaultQuery = ActivityQuery()

    let id: String
    let title: String
    let systemImage: String

    init(_ preset: ActivityPreset) {
        id = preset.id
        title = preset.title
        systemImage = preset.systemImage
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: systemImage))
    }
}
