/// One level-2 section of the guide, shown as its own page.
struct GuideChapter: Equatable, Identifiable {
    let title: String
    let blocks: [GuideBlock]

    var id: String { title }
}
