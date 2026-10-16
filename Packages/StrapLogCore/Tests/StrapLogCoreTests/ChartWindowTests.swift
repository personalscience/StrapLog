import Testing
@testable import StrapLogCore

@Suite("ChartWindow")
struct ChartWindowTests {
    static let start: Int64 = 1_760_000_000_000
    /// One beat a second at 1000 ms for `seconds` seconds.
    static func live(seconds: Int) -> LiveMetrics {
        var live = LiveMetrics()
        for i in 0..<seconds { live.add(tEndMs: start + Int64(i) * 1000, rrMs: 1000) }
        return live
    }

    @Test("ends now and spans the chosen length; .all starts at the recording start")
    func range() {
        let now = Self.start + 20 * 60_000
        let w = ChartWindow(span: .fiveMinutes, nowMs: now, startedAtMs: Self.start)
        #expect(w.endMs == now)
        #expect(w.startMs == now - 300_000)
        #expect(ChartWindow(span: .all, nowMs: now, startedAtMs: Self.start).startMs == Self.start)
    }

    @Test("keeps only points inside the window, both ends inclusive")
    func slice() {
        let pts = (0..<100).map { TrendPoint(atMs: Int64($0) * 1000, value: Double($0)) }
        let w = ChartWindow(span: .oneMinute, nowMs: 90_000, startedAtMs: 0)
        let out = w.visible(pts)
        #expect(out.first?.atMs == 30_000)
        #expect(out.last?.atMs == 90_000)
        #expect(out.count == 61)
        #expect(ChartWindow(span: .oneMinute, nowMs: 500_000, startedAtMs: 0).visible(pts).isEmpty)
    }

    @Test("a long recording's .all view is thinned to maxPoints")
    func thinned() {
        let live = Self.live(seconds: 3 * 3600)
        let w = ChartWindow(span: .all, nowMs: Self.start + 3 * 3_600_000, startedAtMs: Self.start)
        for metric in [ChartMetric.rr, .heartRate] {
            #expect(metric.points(in: w, of: live).count <= ChartWindow.maxPoints)
        }
    }

    @Test("HR is 60000 / RR of the visible beats; α1 comes from its history")
    func metrics() throws {
        let live = Self.live(seconds: 600)
        let w = ChartWindow(span: .twoMinutes, nowMs: Self.start + 599_000, startedAtMs: Self.start)
        let hr = ChartMetric.heartRate.points(in: w, of: live)
        #expect(hr.count == 121)
        #expect(hr.allSatisfy { $0.value == 60 })
        #expect(ChartMetric.alpha1.points(in: w, of: live) == w.visible(live.alpha1History))
    }

    @Test("markers outside the window are dropped")
    func markers() {
        let m = [10_000, 50_000, 95_000].map { RecordingEvent(recordingId: 1, atMs: Int64($0), kind: .marker, note: "a") }
        let w = ChartWindow(span: .oneMinute, nowMs: 90_000, startedAtMs: 0)
        #expect(w.visible(m).map(\.atMs) == [50_000])
    }
}
