import Foundation

/// The user's edits to each activity's marker bar, over the built-in `ActivityPreset.markers`.
/// Stored as JSON `{activityId: [label]}` under `key`; an activity without an entry uses its default.
public struct MarkerPresets: Sendable, Equatable {
    public static let key = "markerPresets"

    private var markers: [String: [String]] = [:]

    public init() {}

    /// The preset stored as `id` (`ActivityPreset.named`) with the user's marker bar, if edited.
    public func preset(_ id: String) -> ActivityPreset {
        let preset = ActivityPreset.named(id)
        return markers[preset.id].map(preset.with(markers:)) ?? preset
    }

    public func isEdited(_ id: String) -> Bool {
        markers[ActivityPreset.named(id).id] != nil
    }

    /// Sets `id`'s bar to `labels`, trimmed, blanks and repeats dropped. A bar equal to the
    /// default drops the edit, so a later change to the default reaches it.
    public mutating func setMarkers(_ labels: [String], for id: String) {
        let preset = ActivityPreset.named(id)
        let clean = Self.normalized(labels)
        markers[preset.id] = clean == preset.markers ? nil : clean
    }

    public mutating func reset(_ id: String) {
        markers[ActivityPreset.named(id).id] = nil
    }

    /// Trimmed, non-empty, first occurrence of each label kept, in order.
    public static func normalized(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Saved edits, or none if the key is unset or unreadable.
    public static func load(from defaults: UserDefaults) -> MarkerPresets {
        guard let data = defaults.data(forKey: key),
              let markers = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return MarkerPresets() }
        var presets = MarkerPresets()
        presets.markers = markers
        return presets
    }

    public func save(to defaults: UserDefaults) throws {
        defaults.set(try JSONEncoder().encode(markers), forKey: Self.key)
    }
}
