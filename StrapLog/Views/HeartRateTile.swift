import SwiftUI

/// Current HR in big digits, with a warning when the strap has lost skin contact.
struct HeartRateTile: View {
    let heartRate: Int?
    let contact: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(heartRate.map(String.init) ?? "--")
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityIdentifier("heartRate")
                Text("bpm").foregroundStyle(.secondary)
            }
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
