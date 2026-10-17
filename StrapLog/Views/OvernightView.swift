import StrapLogCore
import SwiftUI

/// Recording screen for overnight presets: black, no chart or HRV, just how the night will end,
/// the preset's markers and Stop. The phone is free to auto-lock; recording carries on in the background.
struct OvernightView: View {
    let model: RecorderModel
    @State private var confirmingStop = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
            VStack(spacing: 24) {
                Spacer()
                Text(Formats.overnightPlan(model.overnightPlan ?? OvernightPlan(wakeAtMs: nil)))
                    .font(.callout)
                    .accessibilityIdentifier("overnightPlan")
                Text(Formats.bpm(model.heartRate.map(Double.init)))
                    .font(.title2.monospacedDigit())
                Spacer()
                MarkerBar(model: model, nowMs: nowMs)
                Button("Stop…", systemImage: "stop.circle", role: .destructive) { confirmingStop = true }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("stopButton")
            }
            .padding()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .confirmationDialog("Stop this recording and export it?", isPresented: $confirmingStop,
                            titleVisibility: .visible) {
            Button("Stop and export", role: .destructive) { Task { await model.stop() } }
                .accessibilityIdentifier("confirmStop")
        }
    }
}
