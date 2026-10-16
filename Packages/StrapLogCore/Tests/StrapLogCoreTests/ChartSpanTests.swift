import Testing
@testable import StrapLogCore

@Suite("ChartSpan")
struct ChartSpanTests {
    static let hourAndHalf: Int64 = 90 * 60_000

    @Test("no pinch keeps the span")
    func identity() {
        for span in ChartSpan.allCases {
            #expect(span.zoomed(by: 1, elapsedMs: Self.hourAndHalf) == span)
        }
    }

    @Test("pinching out halves toward shorter steps, pinching in lengthens")
    func steps() {
        #expect(ChartSpan.fiveMinutes.zoomed(by: 2.5, elapsedMs: Self.hourAndHalf) == .twoMinutes)
        #expect(ChartSpan.fiveMinutes.zoomed(by: 1 / 3.0, elapsedMs: Self.hourAndHalf) == .fifteenMinutes)
        #expect(ChartSpan.hour.zoomed(by: 0.5, elapsedMs: Self.hourAndHalf) == .all)
        #expect(ChartSpan.all.zoomed(by: 1.5, elapsedMs: Self.hourAndHalf) == .hour)
    }

    @Test("clamps at both ends")
    func clamps() {
        #expect(ChartSpan.oneMinute.zoomed(by: 10, elapsedMs: Self.hourAndHalf) == .oneMinute)
        #expect(ChartSpan.all.zoomed(by: 0.1, elapsedMs: Self.hourAndHalf) == .all)
        #expect(ChartSpan.fiveMinutes.zoomed(by: 0, elapsedMs: Self.hourAndHalf) == .fiveMinutes)
    }

    @Test("early in a recording, .all is never shorter than a minute and fixed steps stay fixed")
    func early() {
        #expect(ChartSpan.all.lengthMs(elapsedMs: 10_000) == 60_000)
        #expect(ChartSpan.oneMinute.zoomed(by: 0.2, elapsedMs: 3 * 60_000) == .fiveMinutes)
        #expect(ChartSpan.all.zoomed(by: 1, elapsedMs: 3 * 60_000) == .all)
    }
}
