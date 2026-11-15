import HRVKit

/// How well heart rate followed the breath in one pacer run of a finished recording
/// (straplog-9fr.6). Derived from the stored beats and pacer events, never stored. The block
/// starts `settleMs` after the pacer start, so the first breaths of settling in do not count,
/// and covers every whole pacer breath up to the stop. Mirrors `rsa.runs` in straplog-py;
/// the two are held together by the parity test on `rsa-calibration.json`.
public struct RSASummary: Sendable, Equatable {
    /// Skipped after each pacer start (`DROP_MS` in `tools/gen_rsa_fixture.py`).
    public static let settleMs: Int64 = 10_000

    public let run: PacerRun
    public let block: RSABlock

    /// One summary per run with at least one whole breath after settling. The whole recording
    /// is cleaned at once (`InstantHR`), as `SessionSummary` cleans it.
    public static func of(_ runs: [PacerRun], tEndMs: [Int64], rrMs: [Double]) -> [RSASummary] {
        guard let originMs = tEndMs.first else { return [] }
        func s(_ ms: Int64) -> Double { Double(ms - originMs) / 1000 }
        let samples = InstantHR.samples(rrMs: rrMs, tEndS: tEndMs.map(s))
        return runs.compactMap { run in
            let block = RSABlock(samples, periodS: run.periodMs / 1000, originS: s(run.originMs),
                                 fromS: s(run.startMs + settleMs), toS: s(run.stopMs))
            return block.breaths.isEmpty ? nil : RSASummary(run: run, block: block)
        }
    }

    /// The summaries for `recording` from its events and beats.
    public static func of(_ recording: Recording, events: [RecordingEvent], beats: [Beat]) -> [RSASummary] {
        let endMs = recording.endedAtMs ?? beats.last?.tEndMsEst ?? recording.startedAtMs
        return of(PacerRun.runs(events, endMs: endMs), tEndMs: beats.map(\.tEndMsEst), rrMs: beats.map(\.rrMs))
    }
}
