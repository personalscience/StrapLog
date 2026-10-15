/// One block of the bundled Markdown guide. Text keeps its inline Markdown (`**bold**`, `*italic*`, `` `code` ``).
enum GuideBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case table(header: [String], rows: [[String]])
    case rule
}
