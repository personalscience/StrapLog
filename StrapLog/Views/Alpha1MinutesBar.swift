import Charts
import StrapLogCore
import SwiftUI

/// Minutes per α1 band as one stacked bar in band colours, with a legend of the bands present.
struct Alpha1MinutesBar: View {
    let minutes: [Alpha1Band: Double]

    private var present: [Alpha1Band] { Alpha1Band.allCases.filter { minutes[$0] != nil } }

    var body: some View {
        if present.isEmpty {
            Text("No α1: under 2 min of clean beats")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Chart(present, id: \.self) { band in
                    BarMark(x: .value("Minutes", minutes[band] ?? 0))
                        .foregroundStyle(band.color)
                }
                .chartXAxis(.hidden)
                .frame(height: 14)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          spacing: 4) {
                    ForEach(present, id: \.self) { band in
                        Label {
                            Text("\(band.label) \(Formats.minutes(minutes[band] ?? 0))")
                        } icon: {
                            Circle().fill(band.color).frame(width: 8, height: 8)
                        }
                        .font(.caption)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("alpha1Minutes")
        }
    }
}
