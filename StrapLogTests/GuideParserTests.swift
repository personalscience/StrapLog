import Foundation
import Testing
import UIKit
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

    @Test("an image line becomes an image block named without its extension")
    func image() {
        let md = "Text\n![The *pacer*](guide-pacer.jpg)\n- a"
        #expect(GuideParser.parse(md) == [
            .paragraph("Text"),
            .image(name: "guide-pacer", caption: "The *pacer*"),
            .bullets(["a"]),
        ])
    }

    @Test("an inline image mid-paragraph is left as text")
    func inlineImageIsText() {
        #expect(GuideParser.parse("See ![x](y.jpg) here") == [.paragraph("See ![x](y.jpg) here")])
    }

    @Test("every image in the bundled guide is in the asset catalog")
    func bundledImagesResolve() {
        let names = Guide.load(from: .main).compactMap { block -> String? in
            if case .image(let name, _) = block { name } else { nil }
        }
        #expect(!names.isEmpty)
        for name in names {
            #expect(UIImage(named: name) != nil, "missing asset \(name)")
        }
    }

    @Test("the bundled guide loads, has every block kind it relies on, and splits into chapters")
    func bundledGuide() {
        let blocks = Guide.load(from: .main)   // unit tests are hosted in the app
        #expect(blocks.first == .heading(level: 1, text: "StrapLog Guide"))
        #expect(blocks.contains { if case .table = $0 { true } else { false } })
        #expect(blocks.contains { if case .numbered = $0 { true } else { false } })
        let book = GuideBook(blocks)
        #expect(book.chapters.first?.title == "Getting started")
        #expect(book.chapters.contains { $0.title == "DFA α1 and training zones" })
        #expect(book.chapters.last?.title == "Troubleshooting")
    }
}

