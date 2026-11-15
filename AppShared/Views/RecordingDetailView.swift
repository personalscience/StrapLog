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
    @State private var viewport = ChartViewport(span: .all)
    @AppStorage(PacerSettings.rateKey) private var pacerRate = BreathingPacer.defaultRate

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

    /// Sets the pacer's remembered rate to the finder's answer (straplog-9fr.10).
    private func useRateButton(_ rate: Double) -> some View {
        let inUse = PacerSettings.rate(pacerRate) == rate
        return Button {
            pacerRate = rate
        } label: {
            Label(Formats.resonanceUse(rate, inUse: inUse), systemImage: inUse ? "checkmark" : "wind")
        }
        .disabled(inUse)
        .accessibilityIdentifier("resonanceUse")
    }

    private func content(_ detail: RecordingDetail) -> some View {
        let rec = detail.recording
        return List {
            Section {
                SessionSummaryCard(summary: detail.summary)
            }
            Section {
                TrendChart(live: detail.live, markers: detail.markers, startedAtMs: rec.startedAtMs,
                           nowMs: detail.endMs, viewport: $viewport, defaultSpan: .all, followLabel: "End")
                    .padding(.vertical, 4)
            }
            if model.capabilities.beatToBeat, let ranking = detail.resonance {
                Section("Resonance") {
                    Text(Formats.resonanceBest(ranking)).font(.subheadline.bold())
                        .accessibilityIdentifier("resonanceBest")
                    ForEach(ranking.entries.indices, id: \.self) { i in
                        Text(Formats.resonanceEntry(ranking.entries[i]))
                            .font(.footnote.monospacedDigit())
                            .fontWeight(i == 0 ? .semibold : .regular)
                            .accessibilityIdentifier("resonanceRate-\(i)")
                    }
                    useRateButton(ranking.best.rate)
                }
            }
            if model.capabilities.beatToBeat && !detail.rsa.isEmpty {
                Section("Heart follows breath") {
                    ForEach(detail.rsa.indices, id: \.self) { i in
                        RSARunRow(summary: detail.rsa[i]).accessibilityIdentifier("rsaRun-\(i)")
                    }
                }
            }
            if !detail.markers.isEmpty {
                Section("Markers") {
                    ForEach(detail.markers.indices, id: \.self) { i in
                        let marker = detail.markers[i]
                        Button {
                            viewport = viewport.jump(toMs: marker.atMs, nowMs: detail.endMs, startedAtMs: rec.startedAtMs)
                        } label: {
                            LabeledContent(marker.markerText, value: Formats.clock(atMs: marker.atMs, tzOffsetS: rec.tzOffsetS))
                        }
                        .tint(.primary)
                        .accessibilityIdentifier("markerRow-\(i)")
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
            Section(AppBrand.current.deviceTitle) {
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
