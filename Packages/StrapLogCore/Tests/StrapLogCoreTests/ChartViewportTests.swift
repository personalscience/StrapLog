import Testing
@testable import StrapLogCore

@Suite("ChartViewport")
struct ChartViewportTests {
    static let start: Int64 = 1_760_000_000_000
    static let now = start + 60 * 60_000
    static let min5: Int64 = 300_000

    @Test("follows the end until panned")
    func follows() {
        let v = ChartViewport(span: .fiveMinutes)
        #expect(!v.isPinned)
        #expect(v.window(nowMs: Self.now, startedAtMs: Self.start).endMs == Self.now)
    }

    @Test("panning back pins; panning past the start clamps to the first full span")
    func panClamps() {
        let back = ChartViewport(span: .fiveMinutes).panned(byMs: -600_000, nowMs: Self.now, startedAtMs: Self.start)
        #expect(back.anchorEndMs == Self.now - 600_000)
        let far = back.panned(byMs: -10 * 3_600_000, nowMs: Self.now, startedAtMs: Self.start)
        #expect(far.anchorEndMs == Self.start + Self.min5)
        #expect(far.window(nowMs: Self.now, startedAtMs: Self.start).startMs == Self.start)
    }

    @Test("panning to (or past) the end follows live again")
    func panToEndRefollows() {
        let back = ChartViewport(span: .fiveMinutes).panned(byMs: -600_000, nowMs: Self.now, startedAtMs: Self.start)
        #expect(!back.panned(byMs: 600_000, nowMs: Self.now, startedAtMs: Self.start).isPinned)
        #expect(!back.panned(byMs: 900_000, nowMs: Self.now, startedAtMs: Self.start).isPinned)
    }

    @Test("the whole-recording span does not pan")
    func allDoesNotPan() {
        let v = ChartViewport(span: .all)
        #expect(v.panned(byMs: -600_000, nowMs: Self.now, startedAtMs: Self.start) == v)
    }

    @Test("a pinned window stays put as time passes")
    func pinnedStays() {
        let back = ChartViewport(span: .fiveMinutes).panned(byMs: -600_000, nowMs: Self.now, startedAtMs: Self.start)
        let later = back.window(nowMs: Self.now + 120_000, startedAtMs: Self.start)
        #expect(later.endMs == Self.now - 600_000)
    }

    @Test("jump centres the marker in the current span and highlights it")
    func jumpCentres() {
        let at = Self.start + 30 * 60_000
        let v = ChartViewport(span: .twoMinutes).jump(toMs: at, nowMs: Self.now, startedAtMs: Self.start)
        #expect(v.span == .twoMinutes)
        #expect(v.highlightMs == at)
        let w = v.window(nowMs: Self.now, startedAtMs: Self.start)
        #expect(w.startMs == at - 60_000 && w.endMs == at + 60_000)
    }

    @Test("jump from the whole recording picks jumpSpan; near the edges it clamps")
    func jumpPicksSpan() {
        let at = Self.start + 30 * 60_000
        #expect(ChartViewport(span: .all).jump(toMs: at, nowMs: Self.now, startedAtMs: Self.start).span == ChartViewport.jumpSpan)
        let early = ChartViewport(span: .fiveMinutes).jump(toMs: Self.start + 10_000, nowMs: Self.now, startedAtMs: Self.start)
        #expect(early.window(nowMs: Self.now, startedAtMs: Self.start).startMs == Self.start)
        let late = ChartViewport(span: .fiveMinutes).jump(toMs: Self.now - 10_000, nowMs: Self.now, startedAtMs: Self.start)
        #expect(!late.isPinned)
        #expect(late.highlightMs == Self.now - 10_000)
    }

    @Test("zoom keeps the anchor and the highlight")
    func zoomKeepsAnchor() {
        let at = Self.start + 30 * 60_000
        let v = ChartViewport(span: .fiveMinutes).jump(toMs: at, nowMs: Self.now, startedAtMs: Self.start)
        let z = v.zoomed(by: 2.5, nowMs: Self.now, startedAtMs: Self.start)
        #expect(z.span == .twoMinutes)
        #expect(z.anchorEndMs == v.anchorEndMs)
        #expect(z.highlightMs == at)
    }
}

extension ChartViewportTests {
    @Test("round-trips through its raw string; junk does not decode")
    func rawValue() {
        let v = ChartViewport(span: .fifteenMinutes, anchorEndMs: 123, highlightMs: 45)
        #expect(ChartViewport(rawValue: v.rawValue) == v)
        #expect(ChartViewport(rawValue: ChartViewport().rawValue) == ChartViewport())
        #expect(ChartViewport(rawValue: "nope") == nil)
    }
}
