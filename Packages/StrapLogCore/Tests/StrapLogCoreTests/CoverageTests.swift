import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("Coverage")
struct CoverageTests {
    func coverage(_ rig: TestRig, _ id: Int64, thresholdMs: Int64 = Coverage.defaultGapThresholdMs) throws -> Coverage {
        try rig.database.writer.read { try Coverage.of(recording: id, gapThresholdMs: thresholdMs, db: $0) }
    }

    @Test("steady 1 Hz data → full coverage, no gaps; jitter under the threshold is ignored")
    func steady() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "x")
        try await rig.play([hr([1000]), .wait(ms: 1000), hr([1000]), .wait(ms: 2900), hr([1000]), .wait(ms: 1000), hr([1000])])
        let c = try coverage(rig, id)
        #expect(c.spanMs == 4900)
        #expect(c.gaps.isEmpty)
        #expect(c.fraction == 1)
    }

    @Test("a silence with no link events is an unbracketed gap and reduces the fraction")
    func unexplainedGap() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "x")
        try await rig.play([hr([1000]), .wait(ms: 1000), hr([1000]), .wait(ms: 8000), hr([1000]), .wait(ms: 1000), hr([1000])])
        let c = try coverage(rig, id)
        #expect(c.spanMs == 10_000)
        #expect(c.gaps == [CoverageGap(startMs: c.gaps[0].startMs, endMs: c.gaps[0].startMs + 8000, events: [])])
        #expect(c.gapMs == 8000)
        #expect(abs(c.fraction - 0.2) < 1e-9)
        #expect(c.unbracketedGaps.count == 1)
    }

    @Test("a relaunch followed by a connect brackets the gap (app killed and restored)")
    func relaunchBracket() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "x")
        try await rig.play([.emit(.connected(deviceId: "H10", firmware: nil)), hr([1000]), .wait(ms: 1000), hr([1000])])
        rig.clock.advance(byMs: 20_000)
        let relaunched = rig.relaunched()
        try await relaunched.resumeIfOpen()
        try await FakeHeartSource(clock: rig.clock, script: [
            .wait(ms: 1000), .emit(.connected(deviceId: "H10", firmware: nil)), .wait(ms: 1000), hr([1000]),
        ]).pump(into: relaunched)
        let c = try coverage(rig, id)
        #expect(c.gaps.map(\.events) == [[.relaunch, .connect]])
        #expect(c.gaps[0].isBracketed)
    }

    @Test("a disconnect with no reconnect inside the gap is not bracketed")
    func downWithoutUp() {
        #expect(!CoverageGap(startMs: 0, endMs: 9000, events: [.disconnect]).isBracketed)
        #expect(!CoverageGap(startMs: 0, endMs: 9000, events: [.connect, .disconnect]).isBracketed)
        #expect(!CoverageGap(startMs: 0, endMs: 9000, events: [.marker, .snapshot]).isBracketed)
        #expect(CoverageGap(startMs: 0, endMs: 9000, events: [.bleOff, .bleOn]).isBracketed)
    }

    @Test("no or one notification → zero span, zero fraction, no gaps")
    func empty() async throws {
        let rig = try TestRig()
        let id = try await rig.session.start(name: "x")
        #expect(try coverage(rig, id) == Coverage(spanMs: 0, gaps: []))
        try await rig.play([hr([1000])])
        #expect(try coverage(rig, id).fraction == 0)
    }
}
