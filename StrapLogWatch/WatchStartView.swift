import StrapLogCore
import SwiftUI

/// Idle: one start button per activity. The phone records, with the wake time and marker bar
/// set in its app; the name is the activity and date. Above them, the strap's HR while the
/// phone is gone.
struct WatchStartView: View {
    let phone: PhoneLink
    let showsStrap: Bool
    let strap: StrapBroadcast?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if showsStrap { StrapHeartView(reading: strap) }
                Text("Not recording").font(.headline)
                ForEach(ActivityPreset.all) { preset in
                    Button {
                        Task { await phone.request(.start(activity: preset.id)) }
                    } label: {
                        Label("Start \(preset.title)", systemImage: preset.systemImage)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .tint(.red)
                    .accessibilityIdentifier("watch.start.\(preset.id)")
                }
            }
        }
    }
}
