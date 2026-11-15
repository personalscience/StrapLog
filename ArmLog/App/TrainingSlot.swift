import Observation
import StrapLogCore

/// Where ArmLog's `TrainingRunner` lands once the database opens: the runner needs the model,
/// which `Launcher` builds later (and may retry), while the scene needs a place to read it from.
@MainActor
@Observable
final class TrainingSlot {
    var runner: TrainingRunner?
}
