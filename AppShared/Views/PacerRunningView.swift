import StrapLogCore
import SwiftUI

/// The pacer screen while `pacer` runs: the flower (pulsing with Heartbeat on, showing the
/// measured breath with My breath on), the heart rate, and Stop and Record, which a running
/// Training run (`trainingRuns`) takes over.
struct PacerRunningView: View {
    let model: RecorderModel
    let pacer: BreathingPacer
    let trainingRuns: Bool

    private static let diameter: CGFloat = 280
    /// With the RSA panel below, so flower, numbers and trace fit one screen.
    private static let smallDiameter: CGFloat = 170

    var body: some View {
        BreathingPacerView(pacer: pacer, pulse: model.ecgShown ? model.ecg.pulse : nil,
                           measured: model.breathOn ? model.breath?.volume : nil,
                           diameter: model.rsaShown ? Self.smallDiameter : Self.diameter)
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
        if !trainingRuns {
            Button("Stop pacer (\(pacer.rateText))", systemImage: "stop.fill") {
                Task { await model.stopPacer() }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("pacerStop")
        }
        if !model.isRecording && !trainingRuns {
            Button("Record this session", systemImage: "record.circle") {
                Task { await model.start(.breathing, name: "") }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("pacerRecord")
        }
    }

    private var breathCaption: String {
        if let breath = model.breath { return breath.caption }
        return model.link.isConnected ? "Waiting for the \(AppBrand.current.device)…" : "Your breath needs the \(AppBrand.current.device) connected"
    }
}
