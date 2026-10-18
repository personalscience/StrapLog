import AppIntents
import SwiftUI

/// A remote display and marker button for the phone's recording: big HR, α1 band, elapsed
/// time, link state. The link starts in `init` so an Action-button intent finds it running.
/// With the complication on the face, watchOS also wakes the app in the background for the
/// phone's updates, which reach the face through `ComplicationFeed`. On screen with the phone
/// gone, `StrapHeart` shows the strap's broadcast HR.
@main
struct StrapLogWatchApp: App {
    @State private var phone: PhoneLink
    @State private var heart: StrapHeart
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let phone = PhoneLink()
        phone.activate()
        AppDependencyManager.shared.add(dependency: phone)
        let heart = StrapHeart(phone: phone)
        phone.onChange = { heart.evaluate() }
        _phone = State(initialValue: phone)
        _heart = State(initialValue: heart)
    }

    var body: some Scene {
        WindowGroup {
            WatchStatusView(phone: phone, heart: heart)
                .onChange(of: scenePhase, initial: true) { _, phase in heart.setForeground(phase == .active) }
        }
        .backgroundTask(.watchConnectivity) {
            await phone.drain()
        }
    }
}
