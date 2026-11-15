import StrapLogCore
import SwiftUI

/// Training mode on the pacer screen (in an app that builds a runner): start a spoken, hands-free script, follow
/// its step and time left, or cancel it. The runner owns the recording and the pacer while it runs.
struct TrainingPanel: View {
    let runner: TrainingRunner

    var body: some View {
        GroupBox("Training") {
            VStack(alignment: .leading, spacing: 10) {
                if runner.isRunning {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Formats.trainingStep(runner.step, secondsLeft: runner.secondsLeft(
                            atMs: Int64(context.date.timeIntervalSince1970 * 1000))))
                            .font(.callout.monospacedDigit())
                            .accessibilityIdentifier("trainingStep")
                    }
                    Button("Cancel training", systemImage: "xmark", role: .destructive) { runner.cancel() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("trainingCancel")
                } else {
                    Text("Eyes closed, hands free: a voice walks each step and records the \(AppBrand.current.device).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(runner.scripts, id: \.name) { script in
                        Button(Formats.trainingScript(script), systemImage: "figure.mind.and.body") {
                            runner.start(script)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("trainingStart-\(script.name)")
                    }
                    if let outcome = runner.outcome {
                        Text(outcome)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("trainingOutcome")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
