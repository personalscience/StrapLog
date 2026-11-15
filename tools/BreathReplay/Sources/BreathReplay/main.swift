// Usage: BreathReplay SAMPLES.csv SEGMENTS.csv > readings.csv
//
// SAMPLES.csv: `at_ms,x_mg,y_mg,z_mg`, oldest first, one sample per row (already placed in time,
// as `acc.at_ms` is, so each goes in as a one-sample notification received at `at_ms`).
// SEGMENTS.csv: `name,from_ms,to_ms,rate,t0_ms`: a fresh `BreathTracker` per row, as the app makes
// one at each `pacer_start`, fed the samples in [from_ms, to_ms) against that pacer (1:1).
// Output: `name,at_ms,volume,still,in_step`, at most one row per 200 ms per segment; empty = nil.
import Foundation
import StrapLogCore

func rows(_ path: String) throws -> [[Substring]] {
    try String(contentsOfFile: path, encoding: .utf8)
        .split(separator: "\n").dropFirst().map { $0.split(separator: ",", omittingEmptySubsequences: false) }
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: BreathReplay SAMPLES.csv SEGMENTS.csv\n".utf8))
    exit(2)
}
let samples = try rows(args[1]).map { r in
    (atMs: Int64(r[0])!, sample: AccSample(deviceNs: 0, x: Int(Double(r[1])!.rounded()),
                                          y: Int(Double(r[2])!.rounded()), z: Int(Double(r[3])!.rounded())))
}
let times = samples.map(\.atMs)

func firstIndex(atOrAfter ms: Int64) -> Int {
    var lo = 0, hi = times.count
    while lo < hi {
        let mid = (lo + hi) / 2
        if times[mid] < ms { lo = mid + 1 } else { hi = mid }
    }
    return lo
}

func text(_ v: Double?) -> String { v.map { String(format: "%.4f", $0) } ?? "" }

var out = "name,at_ms,volume,still,in_step\n"
for seg in try rows(args[2]) {
    let name = String(seg[0]), from = Int64(seg[1])!, to = Int64(seg[2])!
    let pacer = BreathingPacer(breathsPerMinute: Double(seg[3])!, startedAtMs: Int64(seg[4])!)
    var tracker = BreathTracker(pacer: pacer)
    var lastOut: Int64?
    var i = firstIndex(atOrAfter: from)
    while i < samples.count, times[i] < to {
        if let r = tracker.add(receivedAtMs: times[i], samples: [samples[i].sample]),
           lastOut.map({ r.atMs - $0 >= 200 }) ?? true {
            out += "\(name),\(r.atMs),\(text(r.volume)),\(r.still ? 1 : 0),\(text(r.inStep))\n"
            lastOut = r.atMs
        }
        i += 1
    }
}
FileHandle.standardOutput.write(Data(out.utf8))
