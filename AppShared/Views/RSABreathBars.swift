import HRVKit
import StrapLogCore
import SwiftUI

/// One bar per recent pacer breath, oldest on the left: that breath's HR max − min. A breath
/// too gappy to measure is an empty slot, never a zero.
struct RSABreathBars: View {
    let breaths: [BreathSwing]
    let topBpm: Double

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<RSATracker.keptBreaths, id: \.self) { slot in
                let index = slot - (RSATracker.keptBreaths - breaths.count)
                let swing = index >= 0 ? breaths[index].swing : nil
                RoundedRectangle(cornerRadius: 2)
                    .fill(swing == nil ? Color.clear : Color.pink.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44 * CGFloat(min(1, (swing ?? 0) / topBpm)))
            }
        }
        .frame(height: 44, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate swing per breath")
        .accessibilityIdentifier("rsaBars")
    }
}
