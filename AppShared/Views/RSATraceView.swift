import HRVKit
import StrapLogCore
import SwiftUI

/// The last minute of beat-by-beat heart rate scrolling right to left, a dot on each beat, over
/// the pacer's breath wave as a soft band (full lungs at the top) with a line at each turn
/// (teal in, indigo out), as on `EcgStripView`. Each beat sits at the middle of its interval, so
/// the line ends about half a beat behind real time.
struct RSATraceView: View {
    let reading: RSAReading
    let pacer: BreathingPacer

    private static let spanMs = RSADefaults.traceSeconds * 1000
    private static let waveStepMs: Int64 = 200

    var body: some View {
        TimelineView(.animation) { context in
            let right = context.date.timeIntervalSince1970 * 1000
            let left = right - Self.spanMs
            Canvas { gc, size in
                guard let scale = RSATraceScale(reading.trace) else { return }
                let x = { (ms: Double) in CGFloat((ms - left) / Self.spanMs) * size.width }
                let y = { (bpm: Double) in size.height * (0.95 - 0.9 * CGFloat(scale.fraction(bpm))) }

                var band = Path()
                band.move(to: CGPoint(x: 0, y: size.height))
                for p in pacer.volumes(fromMs: Int64(left), throughMs: Int64(right), stepMs: Self.waveStepMs) {
                    band.addLine(to: CGPoint(x: x(Double(p.atMs)), y: size.height * (1 - CGFloat(p.value))))
                }
                band.addLine(to: CGPoint(x: size.width, y: size.height))
                band.closeSubpath()
                gc.fill(band, with: .color(.teal.opacity(0.12)))

                for turn in pacer.transitions(afterMs: Int64(left), throughMs: Int64(right)) {
                    var line = Path()
                    line.move(to: CGPoint(x: x(Double(turn.atMs)), y: 0))
                    line.addLine(to: CGPoint(x: x(Double(turn.atMs)), y: size.height))
                    gc.stroke(line, with: .color((turn.inhaling ? Color.teal : .indigo).opacity(0.5)), lineWidth: 1)
                }

                let points = reading.trace.filter { Double($0.atMs) >= left - 2_000 }
                var hr = Path()
                for (i, p) in points.enumerated() {
                    let point = CGPoint(x: x(Double(p.atMs)), y: y(p.value))
                    if i == 0 { hr.move(to: point) } else { hr.addLine(to: point) }
                }
                gc.stroke(hr, with: .color(.pink), lineWidth: 2)
                for p in points {
                    gc.fill(Path(ellipseIn: CGRect(x: x(Double(p.atMs)) - 2, y: y(p.value) - 2, width: 4, height: 4)),
                            with: .color(.pink))
                }

                gc.draw(Text("\(Int(scale.highBpm))").font(.caption2).foregroundStyle(.secondary),
                        at: CGPoint(x: 4, y: 2), anchor: .topLeading)
                gc.draw(Text("\(Int(scale.lowBpm))").font(.caption2).foregroundStyle(.secondary),
                        at: CGPoint(x: 4, y: size.height - 2), anchor: .bottomLeading)
            }
        }
        .frame(height: 140)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Heart rate over the last minute, against the pacer's breath")
        .accessibilityIdentifier("rsaTrace")
    }
}
