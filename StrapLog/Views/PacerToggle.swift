import StrapLogCore
import SwiftUI

/// Toolbar button that shows or hides the pacer panel, recording or not. Hiding it stops the pacer.
struct PacerToggle: View {
    let model: RecorderModel

    var body: some View {
        Button(model.pacerPanelShown ? "Hide pacer" : "Pacer", systemImage: "wind") {
            Task { await model.showPacerPanel(!model.pacerPanelShown) }
        }
        .symbolVariant(model.pacer != nil ? .circle.fill : .none)
        .accessibilityIdentifier("pacerToggle")
    }
}
