import StrapLogCore
import Testing
@testable import ChileafKit

@Suite("ArmbandTranslator")
struct ArmbandTranslatorTests {
    let accelFrame = hex("ff0a0c40fac008400ba4")

    func ppgBytes(_ counter: UInt8, value: Int16 = 7504) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 20)
        b[0] = UInt8(truncatingIfNeeded: value); b[1] = UInt8(truncatingIfNeeded: value >> 8); b[19] = counter
        return b
    }

    @Test("accelerometer and PPG batch until the HR notification, which flushes them first, in order")
    func flushOnHeartRate() {
        var t = ArmbandTranslator()
        for i in 0..<5 { #expect(t.vendorFrame(accelFrame, atMs: 1000 + Int64(i) * 20).isEmpty) }
        for c in 0..<3 { #expect(t.ppgPacket(ppgBytes(UInt8(c)), atMs: 1000 + Int64(c) * 31).isEmpty) }
        let events = t.heartRate(hex("1048a103"), atMs: 1100)
        guard events.count == 3,
              case .motion(let acc) = events[0].payload, case .ppg(let ppg) = events[1].payload,
              case .heartRate(let bpm, nil, let rr) = events[2].payload else {
            Issue.record("unexpected \(events)"); return
        }
        #expect(acc.count == 5 && events[0].atMs == 1080)
        #expect(acc[0] == AccSample(deviceNs: 0, x: -359, y: 546, z: 703), "counts → mg at 4096/g")
        #expect(acc[1].deviceNs == 20_000_000, "even 20 ms spacing at 50 Hz")
        #expect(ppg.map(\.counter) == [0, 1, 2] && ppg.map(\.receivedAtMs) == [1000, 1031, 1062])
        #expect(bpm == 72 && rr == [0x03a1])
        #expect(t.heartRate(hex("0049"), atMs: 2100).count == 1, "nothing left batched")
    }

    @Test("a full batch flushes without waiting for HR")
    func flushWhenFull() {
        var t = ArmbandTranslator()
        let out = (0..<ArmbandTranslator.maxPpg).flatMap { t.ppgPacket(ppgBytes(UInt8($0)), atMs: Int64($0)) }
        #expect(out.count == 1)
    }

    @Test("re-sent PPG is dropped; reconnecting restarts the counter check and the sample clock")
    func dedupeAndReconnect() {
        var t = ArmbandTranslator()
        for c: UInt8 in [10, 11, 11, 5, 12] { _ = t.ppgPacket(ppgBytes(c), atMs: 0) }
        _ = t.vendorFrame(accelFrame, atMs: 0)
        guard case .ppg(let kept) = t.flush().last?.payload else { Issue.record("no ppg"); return }
        #expect(kept.map(\.counter) == [10, 11, 12])
        t.connected()
        _ = t.ppgPacket(ppgBytes(3), atMs: 0)
        _ = t.vendorFrame(accelFrame, atMs: 0)
        let after = t.flush()
        guard case .motion(let acc) = after.first?.payload, case .ppg(let p) = after.last?.payload else {
            Issue.record("unexpected \(after)"); return
        }
        #expect(acc[0].deviceNs == 0)
        #expect(p.map(\.counter) == [3], "a lower counter after reconnecting is new data")
    }

    @Test("bad bytes produce nothing")
    func garbage() {
        var t = ArmbandTranslator()
        #expect(t.vendorFrame(hex("ff0a0c40fac008400ba5"), atMs: 0).isEmpty)
        #expect(t.vendorFrame(hex("ff0a380126013a016bcb"), atMs: 0).isEmpty, "undecoded frame types are skipped")
        #expect(t.ppgPacket([1, 2], atMs: 0).isEmpty)
        #expect(t.heartRate([], atMs: 0).isEmpty)
    }
}
