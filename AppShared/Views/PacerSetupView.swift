import StrapLogCore
import SwiftUI

/// The pacer screen with no pacer running: pick a rate and an inhale:exhale ratio (both
/// remembered, `PacerSettings`) and start it.
struct PacerSetupView: View {
    let model: RecorderModel
    @AppStorage(PacerSettings.rateKey) private var savedRate = BreathingPacer.defaultRate
    @AppStorage(PacerSettings.ratioKey) private var savedRatio = BreathRatio.default.rawValue

    var body: some View {
        Stepper(value: rate, in: BreathingPacer.rates, step: BreathingPacer.rateStep) {
            Text(Formats.rate(rate.wrappedValue)).monospacedDigit()
        }
        Picker("Inhale to exhale", selection: ratio) {
            ForEach(BreathRatio.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("pacerRatio")
        Button {
            Task { await model.startPacer(breathsPerMinute: rate.wrappedValue, ratio: ratio.wrappedValue) }
        } label: {
            Label("Start pacer", systemImage: "wind").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("pacerStart")
    }

    private var ratio: Binding<BreathRatio> {
        Binding(get: { PacerSettings.ratio(savedRatio) }, set: { savedRatio = $0.rawValue })
    }

    private var rate: Binding<Double> {
        Binding(get: { PacerSettings.rate(savedRate) }, set: { savedRate = $0 })
    }
}
