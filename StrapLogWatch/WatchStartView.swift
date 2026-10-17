import StrapLogCore
import SwiftUI

/// Idle: one start button per activity. The phone records, with the wake time and marker bar
/// set in its app; the name is the activity and date.
struct WatchStartView: View {
    let phone: PhoneLink

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
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
