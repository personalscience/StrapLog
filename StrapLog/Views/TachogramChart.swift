import Charts
import StrapLogCore
import SwiftUI

/// Raw RR over the last 5 minutes.
struct TachogramChart: View {
    let points: [TrendPoint]

    var body: some View {
        if points.count < 2 {
            Text("Waiting for beats…")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            Chart(points, id: \.atMs) { p in
                LineMark(x: .value("Time", p.date), y: .value("RR (ms)", p.value))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel("RR ms")
            .frame(height: 160)
            .accessibilityIdentifier("tachogram")
        }
    }
}
