import SwiftUI

/// A big rounded number over a small caption.
struct LiveMetricLabel: View {
    let value: String
    let caption: String
    var color: Color?
    var size: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: size, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(color ?? .primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
