import AppIntents
import SwiftUI

/// A remote display and marker button for the phone's recording: big HR, α1 band, elapsed
/// time, link state. The link starts in `init` so an Action-button intent finds it running.
@main
struct StrapLogWatchApp: App {
    @State private var phone: PhoneLink

    init() {
        let phone = PhoneLink()
        phone.activate()
        AppDependencyManager.shared.add(dependency: phone)
        _phone = State(initialValue: phone)
    }

    var body: some Scene {
        WindowGroup {
            WatchStatusView(phone: phone)
        }
    }
}
