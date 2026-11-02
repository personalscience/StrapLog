import StrapLogCore
import SwiftUI

/// Pick a rate and ratio and start the pacer, or follow it and stop it. Shown on Home and Recording
/// while `RecorderModel.pacerPanelShown`; the rate and ratio are remembered (`PacerSettings`).
struct PacerSection: View {
    let model: RecorderModel
    @AppStorage(PacerSettings.rateKey) private var savedRate = BreathingPacer.defaultRate
    @AppStorage(PacerSettings.ratioKey) private var savedRatio = BreathRatio.default.rawValue
    @AppStorage(PacerSettings.soundKey) private var soundOn = false

    var body: some View {
        VStack(spacing: 12) {
            if let pacer = model.pacer {
                BreathingPacerView(pacer: pacer)
                Button("Stop pacer (\(pacer.rateText))") { Task { await model.stopPacer() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pacerStop")
                if !model.isRecording {
                    Button("Record this session") { Task { await model.start(.breathing, name: "") } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("pacerRecord")
                }
            } else {
                Stepper(value: rate, in: BreathingPacer.rates, step: BreathingPacer.rateStep) {
                    Text(Formats.rate(rate.wrappedValue)).monospacedDigit()
                }
                Picker("Inhale to exhale", selection: ratio) {
                    ForEach(BreathRatio.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("pacerRatio")
                Button("Start pacer") {
                    Task { await model.startPacer(breathsPerMinute: rate.wrappedValue, ratio: ratio.wrappedValue) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("pacerStart")
            }
            Toggle("Sound", isOn: $soundOn)
                .accessibilityIdentifier("pacerSound")
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private var ratio: Binding<BreathRatio> {
        Binding(get: { PacerSettings.ratio(savedRatio) }, set: { savedRatio = $0.rawValue })
    }

    private var rate: Binding<Double> {
        Binding(get: { PacerSettings.rate(savedRate) }, set: { savedRate = $0 })
    }
}
