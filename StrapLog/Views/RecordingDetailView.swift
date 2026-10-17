import StrapLogCore
import SwiftUI

/// A past recording: summary, the whole chart, markers, editable name/activity/notes, and its
/// export to share or write again.
struct RecordingDetailView: View {
    let model: RecorderModel
    let id: Int64
    @State private var detail: RecordingDetail?
    @State private var edit = RecordingEdit(name: "", activity: ActivityPreset.other.id)
    @State private var exportURL: URL?
    @State private var busy = false

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(detail?.recording.name ?? "")
        .task(id: id) { show(await model.detail(id)) }
    }

    private func content(_ detail: RecordingDetail) -> some View {
        let rec = detail.recording
        return List {
            Section {
                SessionSummaryCard(summary: detail.summary)
            }
            Section {
                TrendChart(live: detail.live, markers: detail.markers, startedAtMs: rec.startedAtMs,
                           nowMs: detail.endMs, spanKey: "detailChartSpan", defaultSpan: .all)
                    .padding(.vertical, 4)
            }
            if !detail.markers.isEmpty {
                Section("Markers") {
                    ForEach(detail.markers.indices, id: \.self) { i in
                        let marker = detail.markers[i]
                        LabeledContent(marker.markerText, value: Formats.clock(atMs: marker.atMs, tzOffsetS: rec.tzOffsetS))
                    }
                }
            }
            Section("Details") {
                TextField("Name", text: $edit.name)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("detailName")
                Picker("Activity", selection: $edit.activity) {
                    ForEach(ActivityPreset.all) { preset in
                        Label(preset.title, systemImage: preset.systemImage).tag(preset.id)
                    }
                }
                TextField("Notes", text: $edit.notes, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityIdentifier("detailNotes")
                Button("Save changes") {
                    run { show(await model.edit(id, edit)) }
                }
                .disabled(busy || edit == RecordingEdit(rec))
                .accessibilityIdentifier("detailSave")
            }
            Section("Export") {
                if let exportURL {
                    Text(Formats.exportLocation(exportURL))
                        .font(.footnote.monospaced())
                    ShareLink(item: exportURL) {
                        Label("Share export", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("detailShare")
                }
                Button(exportURL == nil ? "Export" : "Export again", systemImage: "arrow.clockwise") {
                    run {
                        await model.reexport(id)
                        exportURL = await model.exportURL(for: rec)
                    }
                }
                .disabled(busy)
                .accessibilityIdentifier("detailExport")
            }
            Section("Strap") {
                LabeledContent("Device ID", value: Formats.text(rec.deviceId))
                LabeledContent("Firmware", value: Formats.text(rec.firmware))
                LabeledContent("Battery", value: Formats.batteryRange(start: rec.batteryStart, end: rec.batteryEnd))
            }
        }
    }

    /// Takes a loaded or saved detail; nil (a failure, already in `model.errorMessage`) keeps the old one.
    private func show(_ loaded: RecordingDetail?) {
        guard let loaded else { return }
        detail = loaded
        edit = RecordingEdit(loaded.recording)
        Task { exportURL = await model.exportURL(for: loaded.recording) }
    }

    private func run(_ body: @escaping @MainActor () async -> Void) {
        busy = true
        Task {
            await body()
            busy = false
        }
    }
}
