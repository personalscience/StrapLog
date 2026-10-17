import Observation

/// Starts the app's one long-lived job: open the database, resume an unfinished recording, then
/// feed the heart source into the model. Called from `application(_:didFinishLaunchingWithOptions:)`,
/// which runs for both user launches and Bluetooth state-restoration launches in the background
/// (when no SwiftUI scene, and so no view `.task`, exists). Idempotent.
///
/// Opening can fail: after a reboot, restoration can launch the app before first unlock, when
/// data protection keeps the database unreadable. The failure is kept in `openError` and the
/// next `start()` (on protected data becoming available, or on foreground) tries again.
@MainActor
@Observable
public final class Launcher {
    /// Nil until the database has opened.
    public private(set) var model: RecorderModel?
    /// Why the last attempt to open failed; cleared on success.
    public private(set) var openError: (any Error)?
    @ObservationIgnored private let source: any HeartSource
    @ObservationIgnored private let openModel: @MainActor () throws -> RecorderModel
    @ObservationIgnored private var launch: Task<Void, Never>?
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(source: any HeartSource, openModel: @escaping @MainActor () throws -> RecorderModel) {
        self.source = source
        self.openModel = openModel
    }

    public convenience init(model: RecorderModel, source: any HeartSource) {
        self.init(source: source) { model }
    }

    /// The running job, or nil while the database cannot open; a later call returns the first
    /// successful call's task.
    @discardableResult
    public func start() -> Task<Void, Never>? {
        if let task { return task }
        let model: RecorderModel
        do {
            model = try openModel()
        } catch {
            openError = error
            return nil
        }
        self.model = model
        openError = nil
        let launch = Task { await model.launch() }
        let task = Task { [source] in
            await launch.value
            await model.consume(source)
        }
        self.launch = launch
        self.task = task
        return task
    }

    /// Runs `command` once the open recording (if any) is resumed, so a Shortcut that launches
    /// the app sees it rather than starting a second one. Starts the job if needed; throws the
    /// open error if the database still cannot open.
    public func whenLaunched<T>(_ command: (RecorderModel) async -> T) async throws -> T {
        start()
        guard let model else { throw openError ?? LauncherError.notOpened }
        await launch?.value
        return await command(model)
    }
}
