import StrapLogCore
import SwiftUI

/// Toolbar button that swaps the pacer screen in and out, recording or not. Filled while the
/// pacer runs, so a pacer left running behind Home or Recording stays visible.
struct PacerToggle: View {
    let model: RecorderModel

    var body: some View {
        Button(model.pacerScreenShown ? "Close pacer" : "Pacer", systemImage: "wind") {
            model.showPacerScreen(!model.pacerScreenShown)
        }
        .symbolVariant(model.pacer != nil ? .circle.fill : .none)
        .accessibilityIdentifier("pacerToggle")
    }
}
