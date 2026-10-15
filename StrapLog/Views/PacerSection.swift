import StrapLogCore
import SwiftUI

/// Pick a rate and start the pacer, or follow it and stop it.
struct PacerSection: View {
    let model: RecorderModel
    @State private var rate = BreathingPacer.defaultRate

    var body: some View {
        if let pacer = model.pacer {
            BreathingPacerView(pacer: pacer)
            Button("Stop pacer (\(pacer.note))") { Task { await model.stopPacer() } }
                .accessibilityIdentifier("pacerStop")
        } else {
            Stepper(value: $rate, in: BreathingPacer.rates, step: BreathingPacer.rateStep) {
                Text(Formats.rate(rate)).monospacedDigit()
            }
            Button("Start pacer") { Task { await model.startPacer(breathsPerMinute: rate) } }
                .accessibilityIdentifier("pacerStart")
        }
    }
}
