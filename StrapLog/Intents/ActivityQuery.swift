import AppIntents
import StrapLogCore

/// All of `ActivityPreset.all`, in picker order.
struct ActivityQuery: EnumerableEntityQuery {
    func allEntities() async throws -> [ActivityEntity] {
        ActivityPreset.all.map(ActivityEntity.init)
    }

    func entities(for identifiers: [ActivityEntity.ID]) async throws -> [ActivityEntity] {
        ActivityPreset.all.filter { identifiers.contains($0.id) }.map(ActivityEntity.init)
    }
}
