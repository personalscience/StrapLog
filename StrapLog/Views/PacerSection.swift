import StrapLogCore
import SwiftUI

/// Pick a rate and start the pacer, or follow it and stop it. Shown on Home and Recording
/// while `RecorderModel.pacerPanelShown`; the rate is remembered (`PacerSettings`).
struct PacerSection: View {
    let model: RecorderModel
    @AppStorage(PacerSettings.rateKey) private var savedRate = BreathingPacer.defaultRate

    var body: some View {
        VStack(spacing: 12) {
            if let pacer = model.pacer {
                BreathingPacerView(pacer: pacer)
                Button("Stop pacer (\(pacer.note))") { Task { await model.stopPacer() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pacerStop")
            } else {
                Stepper(value: rate, in: BreathingPacer.rates, step: BreathingPacer.rateStep) {
                    Text(Formats.rate(rate.wrappedValue)).monospacedDigit()
                }
                Button("Start pacer") { Task { await model.startPacer(breathsPerMinute: rate.wrappedValue) } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pacerStart")
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private var rate: Binding<Double> {
        Binding(get: { PacerSettings.rate(savedRate) }, set: { savedRate = $0 })
    }
}
