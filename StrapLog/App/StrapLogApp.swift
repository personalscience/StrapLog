import SwiftUI

@main
struct StrapLogApp: App {
    private let dependencies: Result<AppDependencies, Error>

    init() {
        dependencies = Result { try AppDependencies() }
    }

    var body: some Scene {
        WindowGroup {
            switch dependencies {
            case .success(let deps):
                RootView(model: deps.model)
                    .task {
                        await deps.model.launch()
                        await deps.model.consume(deps.source)
                    }
            case .failure(let error):
                ContentUnavailableView("StrapLog could not start", systemImage: "exclamationmark.triangle",
                                       description: Text(String(describing: error)))
            }
        }
    }
}
