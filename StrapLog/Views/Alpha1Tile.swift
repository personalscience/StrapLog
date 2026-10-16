import StrapLogCore
import SwiftUI

/// Latest DFA α1 with its intensity band; the whole tile takes the band's colour.
struct Alpha1Tile: View {
    let alpha1: Double?

    var body: some View {
        let band = alpha1.map(Alpha1Band.init(alpha1:))
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Formats.decimal(alpha1))
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("α1").foregroundStyle(.secondary)
            }
            Text(band?.label ?? "waiting")
                .font(.caption.bold())
                .foregroundStyle(band?.color ?? .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(12)
        .background((band?.color ?? .gray).opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("alpha1")
    }
}
