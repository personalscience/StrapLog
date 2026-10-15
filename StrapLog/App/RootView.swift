import HRVKit
import StrapLogCore
import SwiftUI

/// Placeholder screen for the Phase 0 scaffold. Phase 3 replaces it with Home and Recording.
struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("StrapLog")
                .font(.largeTitle.bold())
            Text("HRVKit \(HRVKit.version) · Core \(StrapLogCore.version)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("versionLabel")
        }
        .padding()
    }
}

#Preview {
    RootView()
}
