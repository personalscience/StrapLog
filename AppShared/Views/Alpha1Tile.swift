import StrapLogCore
import SwiftUI

/// Latest DFA α1 with its intensity band; the whole tile takes the band's colour.
struct Alpha1Tile: View {
    let alpha1: Double?

    var body: some View {
        let band = alpha1.map(Alpha1Band.init(alpha1:))
        VStack(alignment: .leading, spacing: 2) {
            HeroNumber(value: Formats.decimal(alpha1), unit: "α1")
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
