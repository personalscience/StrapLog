import StrapLogCore
import SwiftUI

/// A circle that fills on the in-breath and empties on the out-breath, with a tap at each turn.
struct BreathingPacerView: View {
    let pacer: BreathingPacer

    var body: some View {
        TimelineView(.animation) { context in
            let phase = pacer.phase(atMs: Int64(context.date.timeIntervalSince1970 * 1000))
            VStack(spacing: 12) {
                Circle()
                    .fill(.teal.opacity(0.25 + 0.5 * phase.volume))
                    .scaleEffect(0.35 + 0.65 * phase.volume)
                    .frame(width: 180, height: 180)
                Text(phase.instruction)
                    .font(.title3.bold())
                    .accessibilityIdentifier("pacerInstruction")
                Text(Formats.countdown(seconds: phase.secondsLeft))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .sensoryFeedback(.impact(weight: .light), trigger: phase.inhaling)
        }
    }
}
