import SwiftUI

/// A hero tile's big digits and unit. Scales with Dynamic Type, then shrinks to fit its tile.
struct HeroNumber: View {
    let value: String
    let unit: String
    var identifier = ""
    @ScaledMetric(relativeTo: .largeTitle) private var size = 64.0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .accessibilityIdentifier(identifier)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}
