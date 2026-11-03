import SwiftUI

/// The sign that a marker was saved: the view pops and flashes green. It fires when the count
/// rises and this view made the latest marker, so it confirms the save rather than the touch,
/// and a repeat of the same label fires again. Reduce Motion keeps the flash and drops the pop.
struct MarkerLandedEffect: ViewModifier {
    static let defaultCornerRadius: CGFloat = 12

    let markerCount: Int
    let isLatest: Bool
    let scale: CGFloat
    let cornerRadius: CGFloat
    @State private var landings = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Values: Sendable {
        var scale: CGFloat = 1
        var flash: Double = 0
    }

    func body(content: Content) -> some View {
        let peak = reduceMotion ? 1 : scale
        let cornerRadius = cornerRadius
        return content
            .keyframeAnimator(initialValue: Values(), trigger: landings) { view, values in
                view
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.green.opacity(values.flash))
                            .allowsHitTesting(false)
                    }
                    .scaleEffect(values.scale)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(peak, duration: 0.12)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.flash) {
                    LinearKeyframe(0.6, duration: 0.08)
                    LinearKeyframe(0.6, duration: 0.3)
                    LinearKeyframe(0, duration: 0.8)
                }
            }
            .onChange(of: markerCount) { old, new in
                if new > old, isLatest { landings += 1 }
            }
    }
}

extension View {
    /// `MarkerLandedEffect`.
    func markerLanded(markerCount: Int, isLatest: Bool, scale: CGFloat = 1.2,
                      cornerRadius: CGFloat = MarkerLandedEffect.defaultCornerRadius) -> some View {
        modifier(MarkerLandedEffect(markerCount: markerCount, isLatest: isLatest, scale: scale, cornerRadius: cornerRadius))
    }
}
