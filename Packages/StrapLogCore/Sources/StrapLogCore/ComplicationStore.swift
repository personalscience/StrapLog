import Foundation

/// The `ComplicationSnapshot` on the face, shared by the Watch app (which writes it) and its
/// widget extension (which draws it) through their App Group's defaults.
public struct ComplicationStore: @unchecked Sendable {
    public static let appGroup = "group.com.personalscience.straplog"
    /// The complication widget's kind, which the Watch app reloads.
    public static let widgetKind = "StrapLogComplication"
    static let key = "complication"

    // UserDefaults is thread-safe but not marked Sendable.
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The App Group's store; the standard defaults if the group is missing from the entitlements.
    public static var shared: ComplicationStore {
        ComplicationStore(defaults: UserDefaults(suiteName: appGroup) ?? .standard)
    }

    /// The saved snapshot, or nil before the first one or when unreadable (an older app's).
    public func load() -> ComplicationSnapshot? {
        defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(ComplicationSnapshot.self, from: $0) }
    }

    public func save(_ snapshot: ComplicationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
