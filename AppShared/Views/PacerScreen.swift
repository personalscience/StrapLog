import StrapLogCore
import SwiftUI

/// The pacer on a screen of its own, shown in place of Home or Recording while
/// `RecorderModel.pacerScreenShown`; the toolbar's wind button goes back and forth, and a
/// running pacer keeps going behind the other screens. Pick a rate and ratio and start it, or
/// follow it and stop it. The rate and ratio are remembered (`PacerSettings`). With Heartbeat
/// on, the strap streams its ECG while this screen is up, shown as a strip with the breath's
/// turns marked, and the flower pulses on each beat.
struct PacerScreen: View {
    let model: RecorderModel
    @AppStorage(PacerSettings.rateKey) private var savedRate = BreathingPacer.defaultRate
    @AppStorage(PacerSettings.ratioKey) private var savedRatio = BreathRatio.default.rawValue
    @AppStorage(PacerSettings.soundKey) private var soundOn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let pacer = model.pacer {
                    BreathingPacerView(pacer: pacer, pulse: model.ecgShown ? model.ecg.pulse : nil,
                                       measured: model.breathOn ? model.breath?.volume : nil)
                    if model.breathOn {
                        Text(breathCaption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("breathCaption")
                    }
                    Text(model.heartRate.map { "\($0) bpm" } ?? "-- bpm")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("pacerHeartRate")
                    Button("Stop pacer (\(pacer.rateText))", systemImage: "stop.fill") {
                        Task { await model.stopPacer() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pacerStop")
                    if !model.isRecording {
                        Button("Record this session", systemImage: "record.circle") {
                            Task { await model.start(.breathing, name: "") }
                        }
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
                    Button {
                        Task { await model.startPacer(breathsPerMinute: rate.wrappedValue, ratio: ratio.wrappedValue) }
                    } label: {
                        Label("Start pacer", systemImage: "wind").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pacerStart")
                }
                if model.ecgShown {
                    if model.ecg.isEmpty {
                        Text(model.link.isConnected ? "Waiting for ECG…" : "ECG needs the \(AppBrand.current.device) connected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 110)
                            .accessibilityIdentifier("ecgWaiting")
                    } else {
                        EcgStripView(trace: model.ecg, pacer: model.pacer)
                    }
                }
                Toggle("Sound", isOn: $soundOn)
                    .accessibilityIdentifier("pacerSound")
                if model.capabilities.ecg {
                    Toggle(isOn: .init(get: { model.ecgOn }, set: { model.setECG($0) })) {
                        Text("Heartbeat (ECG)")
                        Text("The \(AppBrand.current.device)'s live ECG, with a pulse on each beat")
                    }
                    .accessibilityIdentifier("pacerECG")
                }
                Toggle(isOn: .init(get: { model.breathOn }, set: { model.setBreath($0) })) {
                    Text("My breath")
                    Text("The flower follows your breathing, read by the \(AppBrand.current.device); the dashed ring is the pacer")
                }
                .accessibilityIdentifier("pacerBreath")
            }
            .padding()
        }
    }

    private var breathCaption: String {
        if let breath = model.breath { return breath.caption }
        return model.link.isConnected ? "Waiting for the \(AppBrand.current.device)…" : "Your breath needs the \(AppBrand.current.device) connected"
    }

    private var ratio: Binding<BreathRatio> {
        Binding(get: { PacerSettings.ratio(savedRatio) }, set: { savedRatio = $0.rawValue })
    }

    private var rate: Binding<Double> {
        Binding(get: { PacerSettings.rate(savedRate) }, set: { savedRate = $0 })
    }
}
