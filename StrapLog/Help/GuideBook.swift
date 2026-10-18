/// The guide as the Help screen shows it: a title, an introduction, then one page per level-2 heading.
struct GuideBook: Equatable {
    let title: String
    let intro: [GuideBlock]
    let chapters: [GuideChapter]

    /// Takes the title from a leading level-1 heading and splits the rest at level-2 headings.
    /// Rules that only separate chapters are dropped; a page needs no divider at its end.
    init(_ blocks: [GuideBlock]) {
        var rest = blocks[...]
        if case .heading(1, let text)? = rest.first {
            title = text
            rest = rest.dropFirst()
        } else {
            title = "Guide"
        }

        var intro: [GuideBlock] = []
        var chapters: [GuideChapter] = []
        for block in rest {
            if case .heading(2, let text) = block {
                chapters.append(GuideChapter(title: text, blocks: []))
            } else if let last = chapters.popLast() {
                chapters.append(GuideChapter(title: last.title, blocks: last.blocks + [block]))
            } else {
                intro.append(block)
            }
        }
        self.intro = Self.trimmed(intro)
        self.chapters = chapters.map { GuideChapter(title: $0.title, blocks: Self.trimmed($0.blocks)) }
    }

    private static func trimmed(_ blocks: [GuideBlock]) -> [GuideBlock] {
        Array(blocks.reversed().drop { $0 == .rule }.reversed())
    }
}
