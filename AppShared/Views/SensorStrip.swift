import StrapLogCore
import SwiftUI

/// What an optical sensor (BaroLog's armband) adds under the chart: the live pulse wave, its
/// size, how much the arm is moving, and the band's temperatures. Shown only when the sensor
/// has them (`SensorCapabilities.optical`).
struct SensorStrip: View {
    let model: RecorderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PulseWave(values: model.ppg.values)
                .frame(height: 44)
                .overlay {
                    if model.ppg.offSkin {
                        Text("Off the skin").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("pulseWave")
            Text(Formats.pulseAndMovement(amplitude: model.ppg.pulseAmplitude, movementMg: model.movementMg))
                .accessibilityIdentifier("pulseAndMovement")
            Text(Formats.temperatures(model.temperature))
                .accessibilityIdentifier("temperatures")
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
    }
}
