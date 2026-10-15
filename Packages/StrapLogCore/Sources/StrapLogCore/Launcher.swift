/// Starts the app's one long-lived job: resume an unfinished recording, then feed the heart
/// source into the model. Called from `application(_:didFinishLaunchingWithOptions:)`, which
/// runs for both user launches and Bluetooth state-restoration launches in the background
/// (when no SwiftUI scene, and so no view `.task`, exists). Idempotent.
@MainActor
public final class Launcher {
    private let model: RecorderModel
    private let source: any HeartSource
    private var task: Task<Void, Never>?

    public init(model: RecorderModel, source: any HeartSource) {
        self.model = model
        self.source = source
    }

    /// The running job; a second call returns the first call's task.
    @discardableResult
    public func start() -> Task<Void, Never> {
        if let task { return task }
        let task = Task { [model, source] in
            await model.launch()
            await model.consume(source)
        }
        self.task = task
        return task
    }
}
