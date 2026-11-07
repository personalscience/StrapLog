import StrapLogCore
import SwiftUI

/// A flower that opens on the in-breath and closes on the out-breath: six petals spread from
/// the centre and turn slowly as the lungs fill, the colour drifts from teal (in) toward indigo
/// (out), and a faint ring marks full. With the ECG on, the centre beats with the heart: a soft
/// glow and a ring that flares from the flower's edge on each R peak, to start a breath on a
/// beat. A tap at each turn. Calm on purpose: everything moves with the breath or the heart,
/// nothing on its own.
struct BreathingPacerView: View {
    let pacer: BreathingPacer
    var pulse: BeatPulse?
    var diameter: CGFloat = 280

    private static let petals = 6

    var body: some View {
        TimelineView(.animation) { context in
            let nowMs = context.date.timeIntervalSince1970 * 1000
            let phase = pacer.phase(atMs: Int64(nowMs))
            let volume = phase.volume
            let beat = pulse?.intensity(atMs: nowMs) ?? 0
            let bloom = 0.45 + 0.55 * volume
            let tint = Color.teal.mix(with: .indigo, by: phase.inhaling ? 0 : 0.5 * (1 - volume))
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.25), lineWidth: 1.5)
                    ForEach(0..<Self.petals, id: \.self) { i in
                        Circle()
                            .fill(tint.gradient.opacity(0.22 + 0.18 * volume))
                            .frame(width: diameter / 2, height: diameter / 2)
                            .offset(y: -diameter / 4 * volume)
                            .rotationEffect(.degrees(Double(i) * 360 / Double(Self.petals) + 45 * volume))
                    }
                    .scaleEffect(bloom)
                    Circle()
                        .stroke(Color.pink.opacity(0.55 * beat), lineWidth: 3)
                        .scaleEffect(bloom * (1.04 - 0.06 * beat))
                    Circle()
                        .fill(tint.opacity(0.35 + 0.35 * beat))
                        .frame(width: diameter * 0.18, height: diameter * 0.18)
                        .scaleEffect(0.8 + 0.4 * volume + 0.15 * beat)
                }
                .frame(width: diameter, height: diameter)
                .accessibilityHidden(true)
                Text(phase.instruction)
                    .font(.title2.bold())
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
