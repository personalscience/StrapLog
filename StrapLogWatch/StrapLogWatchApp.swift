import SwiftUI

/// A remote display for the phone's recording: big HR, α1 band, elapsed time, link state.
@main
struct StrapLogWatchApp: App {
    @State private var phone = PhoneLink()

    var body: some Scene {
        WindowGroup {
            WatchStatusView(phone: phone)
                .task { phone.activate() }
        }
    }
}
