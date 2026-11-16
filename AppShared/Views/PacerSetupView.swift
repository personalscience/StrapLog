import StrapLogCore
import SwiftUI

/// The pacer screen with no pacer running: pick a rate (the model's `pacerRate`) and an
/// inhale:exhale ratio (both remembered, `PacerSettings`) and start it. Shows your resonance
/// rate once there is one, with a button to pace at it.
struct PacerSetupView: View {
    let model: RecorderModel
    @AppStorage(PacerSettings.ratioKey) private var savedRatio = BreathRatio.default.rawValue

    var body: some View {
        if model.capabilities.beatToBeat, let resonance = model.resonance {
            HStack {
                Text(Formats.resonanceRate(resonance)).font(.subheadline)
                    .accessibilityIdentifier("resonanceRate")
                Spacer()
                if model.pacerRate != resonance.rate {
                    Button("Use") { model.setPacerRate(resonance.rate) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("resonanceRateUse")
                }
            }
        }
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
        Binding(get: { model.pacerRate }, set: { model.setPacerRate($0) })
    }
}
