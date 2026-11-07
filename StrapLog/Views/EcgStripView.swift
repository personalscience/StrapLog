import StrapLogCore
import SwiftUI

/// The last few seconds of live ECG scrolling right to left, a dot over each R peak found, and,
/// with the pacer running, a line at each turn of the breath (teal in, indigo out). The right
/// edge trails real time by `lagMs` because the strap sends ECG in half-second batches.
struct EcgStripView: View {
    let trace: EcgTrace
    let pacer: BreathingPacer?
    var spanMs = 5_000.0

    private static let lagMs = 700.0

    var body: some View {
        TimelineView(.animation) { context in
            let right = context.date.timeIntervalSince1970 * 1000 - Self.lagMs
            let left = right - spanMs
            Canvas { gc, size in
                let points = trace.points(fromMs: left - 50)
                guard let low = points.map(\.microvolts).min(), let high = points.map(\.microvolts).max() else { return }
                let range = Double(max(high - low, 200))
                let x = { (ms: Double) in CGFloat((ms - left) / spanMs) * size.width }
                let y = { (uv: Int) in size.height * (0.92 - 0.8 * CGFloat(Double(uv - low) / range)) }

                for turn in pacer?.transitions(afterMs: Int64(left), throughMs: Int64(right)) ?? [] {
                    var line = Path()
                    line.move(to: CGPoint(x: x(Double(turn.atMs)), y: 0))
                    line.addLine(to: CGPoint(x: x(Double(turn.atMs)), y: size.height))
                    gc.stroke(line, with: .color(turn.inhaling ? .teal : .indigo), lineWidth: 2)
                }
                var wave = Path()
                for (i, p) in points.enumerated() where p.atMs <= right {
                    let point = CGPoint(x: x(p.atMs), y: y(p.microvolts))
                    if i == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
                }
                gc.stroke(wave, with: .color(.primary), lineWidth: 1.5)
                for beat in trace.beatsMs where beat >= left && beat <= right {
                    gc.fill(Path(ellipseIn: CGRect(x: x(beat) - 3, y: 2, width: 6, height: 6)), with: .color(.pink))
                }
            }
        }
        .frame(height: 110)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Live ECG")
        .accessibilityIdentifier("ecgStrip")
    }
}
