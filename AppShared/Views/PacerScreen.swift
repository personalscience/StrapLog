import StrapLogCore
import SwiftUI

/// The pacer on a screen of its own, shown in place of Home or Recording while
/// `RecorderModel.pacerScreenShown`; the toolbar's wind button goes back and forth, and a
/// running pacer keeps going behind the other screens. It composes `PacerSetupView` (pick a rate
/// and ratio and start) or `PacerRunningView` (follow it and stop it) with the panels and
/// toggles. With Heartbeat on, the strap streams its ECG while this screen is up, shown as a
/// strip with the breath's turns marked, and the flower pulses on each beat. With Heart follows
/// breath on (a sensor with beat-accurate RR), `RSAPanel` shows HR against the breath and the
/// flower shrinks to make room. With a `training`
/// runner (ArmLog), the Training panel sits on top, and while a run is going the runner alone
/// starts and stops the pacer and the recording.
struct PacerScreen: View {
    let model: RecorderModel
    var training: TrainingRunner?
    @AppStorage(PacerSettings.soundKey) private var soundOn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let training { TrainingPanel(runner: training) }
                if let pacer = model.pacer {
                    PacerRunningView(model: model, pacer: pacer, trainingRuns: trainingRuns)
                } else if !trainingRuns {
                    PacerSetupView(model: model)
                }
                if model.rsaShown, let pacer = model.pacer {
                    RSAPanel(reading: model.rsa, pacer: pacer, connected: model.link.isConnected)
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
                if model.capabilities.beatToBeat {
                    Toggle(isOn: .init(get: { model.rsaOn }, set: { model.setRSA($0) })) {
                        Text("Heart follows breath")
                        Text("Your heart rate beat by beat against the pacer: how much it swings with each breath, and how closely it follows")
                    }
                    .accessibilityIdentifier("pacerRSA")
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

    private var trainingRuns: Bool { training?.isRunning == true }
}
