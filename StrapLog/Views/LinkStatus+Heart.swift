import StrapLogCore
import SwiftUI

/// How the toolbar heart shows the strap link.
extension LinkStatus {
    var isConnected: Bool {
        if case .connected = self { true } else { false }
    }

    var heartSymbol: String {
        switch self {
        case .connected, .searching: "heart.fill"
        case .disconnected, .bluetoothOff: "heart.slash.fill"
        }
    }

    var heartColor: Color {
        switch self {
        case .connected: .red
        case .searching: .gray
        case .disconnected, .bluetoothOff: .orange
        }
    }
}
