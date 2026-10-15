import StrapLogCore
import SwiftUI

/// Strap connection, battery and current HR.
struct LinkStatusRow: View {
    let model: RecorderModel

    var body: some View {
        HStack {
            Label(Formats.link(model.link), systemImage: model.link.isConnected ? "heart.fill" : "heart.slash")
                .foregroundStyle(model.link.isConnected ? .red : .secondary)
                .accessibilityIdentifier("linkStatus")
            Spacer()
            if let battery = model.battery {
                Label("\(battery)%", systemImage: "battery.75percent")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

private extension LinkStatus {
    var isConnected: Bool {
        if case .connected = self { true } else { false }
    }
}
