import StrapLogCore
import SwiftUI

/// Strap and recording diagnostics, off the main screen.
struct DeviceSheet: View {
    let model: RecorderModel
    @Environment(\.dismiss) private var dismiss
    private let info = Bundle.main.infoDictionary ?? [:]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let nowMs = Int64(context.date.timeIntervalSince1970 * 1000)
                List {
                    Section {
                        LabeledContent("Link", value: Formats.link(model.link))
                        LabeledContent("Device ID", value: Formats.deviceId(model.link))
                            .accessibilityIdentifier("deviceId")
                        LabeledContent("Firmware", value: Formats.text(model.firmware))
                        LabeledContent("Serial", value: Formats.text(model.serialNumber))
                        LabeledContent("Battery", value: Formats.battery(model.battery))
                        LabeledContent("Contact", value: model.contact.map(Formats.contact) ?? "--")
                    } header: {
                        Text("Strap")
                    } footer: {
                        if let hint = Formats.strapHint(model.link) { Text(hint) }
                    }
                    Section {
                        Button("Use a Different Strap", role: .destructive) { model.forgetStrap() }
                            .disabled(model.isRecording)
                            .accessibilityIdentifier("forgetStrap")
                    } footer: {
                        Text(Formats.switchStrapFooter(recording: model.isRecording))
                    }
                    if model.isRecording {
                        Section("Recording") {
                            LabeledContent("Beats") {
                                Text("\(model.beatCount)").accessibilityIdentifier("beatCount")
                            }
                            LabeledContent("Since last notification",
                                           value: model.lastHeardAtMs.map { Formats.gap(ms: nowMs - $0) } ?? "--")
                            LabeledContent("Longest gap", value: Formats.gap(ms: model.longestGapMs))
                        }
                    }
                    if let snapshot = model.lastSnapshot {
                        Section("Last export") {
                            Text(Formats.exportLocation(snapshot))
                                .font(.footnote.monospaced())
                        }
                    }
                    Section("App") {
                        LabeledContent("Build", value: Formats.build(info))
                            .accessibilityIdentifier("appBuild")
                        LabeledContent("Built", value: Formats.text(info["StrapLogBuiltAt"] as? String))
                    }
                }
            }
            .navigationTitle("Strap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("deviceDone")
                }
            }
        }
    }
}
