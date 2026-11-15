import HRVKit
import StrapLogCore
import SwiftUI

/// The headline: the fitted swing over the last four breaths and how much of the heart's
/// variation follows the breath (sync), then where HR peaks in the breath, coloured by
/// `RSAJudgement`.
struct RSASwingView: View {
    let reading: RSAReading
    let pacer: BreathingPacer

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack {
                    Text(Formats.rsaSwing(reading.fit))
                        .font(.title.monospacedDigit().bold())
                        .accessibilityIdentifier("rsaSwing")
                    Text("Swing").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                VStack {
                    Text(Formats.rsaSync(reading.fit))
                        .font(.title.monospacedDigit().bold())
                        .accessibilityIdentifier("rsaSync")
                    Text("Sync").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            if let fit = reading.fit {
                Text(Formats.rsaPeak(fit, pacer: pacer))
                    .font(.footnote)
                    .foregroundStyle(color(reading.judgement))
                    .accessibilityIdentifier("rsaPeak")
            }
        }
    }

    private func color(_ judgement: RSAJudgement?) -> Color {
        switch judgement {
        case .onTarget: .green
        case .near: .orange
        case .off: .red
        case .noRhythm, nil: .secondary
        }
    }
}
