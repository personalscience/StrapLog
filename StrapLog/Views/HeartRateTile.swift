import SwiftUI

/// Current HR in big digits, with a warning when the strap has lost skin contact.
struct HeartRateTile: View {
    let heartRate: Int?
    let contact: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HeroNumber(value: heartRate.map(String.init) ?? "--", unit: "bpm", identifier: "heartRate")
            if contact == false {
                Label(Formats.contact(false), systemImage: "hand.raised.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("contact")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }
}
