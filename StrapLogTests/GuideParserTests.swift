import Foundation
import Testing
@testable import StrapLog

@Suite("GuideParser")
struct GuideParserTests {
    @Test("headings, paragraphs joined across lines, rules")
    func basics() {
        let md = "# Title\n\nOne\ntwo.\n\n---\n\n### Sub"
        #expect(GuideParser.parse(md) == [
            .heading(level: 1, text: "Title"),
            .paragraph("One two."),
            .rule,
            .heading(level: 3, text: "Sub"),
        ])
    }

    @Test("bullet and numbered lists split when the kind changes")
    func lists() {
        let md = "- a\n- **b**\n1. one\n2. two"
        #expect(GuideParser.parse(md) == [.bullets(["a", "**b**"]), .numbered(["one", "two"])])
    }

    @Test("a paragraph directly before a list stays separate")
    func paragraphThenList() {
        #expect(GuideParser.parse("So:\n- x") == [.paragraph("So:"), .bullets(["x"])])
    }

    @Test("pipe tables drop the separator row and trim cells")
    func table() {
        let md = "| A | B |\n|---|:-:|\n| 1 | **2** |\n| 3 | 4 |"
        #expect(GuideParser.parse(md) == [.table(header: ["A", "B"], rows: [["1", "**2**"], ["3", "4"]])])
    }

    @Test("the bundled guide loads and has every block kind it relies on")
    func bundledGuide() {
        let blocks = Guide.load(from: .main)   // unit tests are hosted in the app
        #expect(blocks.first == .heading(level: 1, text: "Understanding Your Numbers"))
        #expect(blocks.contains { if case .table = $0 { true } else { false } })
        #expect(blocks.contains { if case .numbered = $0 { true } else { false } })
        #expect(blocks.contains(.heading(level: 3, text: "DFA α1 (alpha-1)")))
    }
}

