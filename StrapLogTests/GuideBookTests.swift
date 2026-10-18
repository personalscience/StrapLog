import Testing
@testable import StrapLog

@Suite("GuideBook")
struct GuideBookTests {
    @Test("the leading level-1 heading is the title; level-2 headings start chapters")
    func split() {
        let book = GuideBook([
            .heading(level: 1, text: "T"), .paragraph("intro"), .rule,
            .heading(level: 2, text: "A"), .paragraph("a"), .heading(level: 3, text: "A.1"), .rule,
            .heading(level: 2, text: "B"), .bullets(["b"]),
        ])
        #expect(book.title == "T")
        #expect(book.intro == [.paragraph("intro")])
        #expect(book.chapters == [
            GuideChapter(title: "A", blocks: [.paragraph("a"), .heading(level: 3, text: "A.1")]),
            GuideChapter(title: "B", blocks: [.bullets(["b"])]),
        ])
    }

    @Test("without a level-1 heading the title is Guide and everything is intro")
    func untitled() {
        let book = GuideBook([.paragraph("The guide is missing from this build.")])
        #expect(book.title == "Guide")
        #expect(book.intro == [.paragraph("The guide is missing from this build.")])
        #expect(book.chapters.isEmpty)
    }

    @Test("a rule inside a chapter stays")
    func innerRule() {
        let book = GuideBook([.heading(level: 2, text: "A"), .paragraph("x"), .rule, .paragraph("y")])
        #expect(book.chapters.first?.blocks == [.paragraph("x"), .rule, .paragraph("y")])
    }
}
