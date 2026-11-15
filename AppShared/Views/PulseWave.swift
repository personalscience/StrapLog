import SwiftUI

/// Raw PPG values drawn left to right, scaled to fill the height. Flipped on the assumption
/// (unchecked for this band) that it reports light received, which falls as blood arrives, so
/// each pulse peaks upward. If pulses look upside down on the phone, drop the flip.
struct PulseWave: View {
    let values: [Int]

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, let lo = values.min(), let hi = values.max(), hi > lo else { return }
            let dx = size.width / CGFloat(values.count - 1)
            var path = Path()
            for (i, v) in values.enumerated() {
                let y = CGFloat(v - lo) / CGFloat(hi - lo) * size.height
                let point = CGPoint(x: CGFloat(i) * dx, y: y)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(.pink), lineWidth: 1.5)
        }
    }
}
