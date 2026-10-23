import Foundation

/// Splits the guide's Markdown into blocks. Supports exactly what `Guide.md` uses:
/// ATX headings, paragraphs, `-` and `1.` lists, pipe tables, `---` rules and one-line images.
enum GuideParser {
    static func parse(_ markdown: String) -> [GuideBlock] {
        var blocks: [GuideBlock] = []
        var paragraph: [String] = []
        var list: (ordered: Bool, items: [String])?
        var table: [[String]] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            if let l = list { blocks.append(l.ordered ? .numbered(l.items) : .bullets(l.items)) }
            if let header = table.first { blocks.append(.table(header: header, rows: Array(table.dropFirst()))) }
            paragraph = []; list = nil; table = []
        }

        for raw in markdown.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line == "---" {
                flush(); blocks.append(.rule)
            } else if let (name, caption) = image(line) {
                flush(); blocks.append(.image(name: name, caption: caption))
            } else if let (level, text) = heading(line) {
                flush(); blocks.append(.heading(level: level, text: text))
            } else if line.hasPrefix("|") {
                if table.isEmpty { flush() }
                if !isSeparatorRow(line) { table.append(cells(line)) }
            } else if let (ordered, item) = listItem(line) {
                if list?.ordered != ordered { flush() }
                list = (ordered, (list?.items ?? []) + [item])
            } else if var l = list, !l.items.isEmpty {
                l.items[l.items.count - 1] += " " + line   // continuation of the last item
                list = l
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    private static func heading(_ line: String) -> (Int, String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    /// `![caption](file.jpg)` → the file's name without its extension, and the caption.
    private static func image(_ line: String) -> (String, String)? {
        guard line.hasPrefix("!["), line.hasSuffix(")"),
              let mid = line.range(of: "](") else { return nil }
        let caption = String(line[line.index(line.startIndex, offsetBy: 2)..<mid.lowerBound])
        let file = line[mid.upperBound..<line.index(before: line.endIndex)]
        let name = file.split(separator: ".").first.map(String.init) ?? ""
        return name.isEmpty ? nil : (name, caption)
    }

    private static func listItem(_ line: String) -> (ordered: Bool, String)? {
        if line.hasPrefix("- ") { return (false, String(line.dropFirst(2))) }
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, line.dropFirst(digits.count).hasPrefix(". ") else { return nil }
        return (true, String(line.dropFirst(digits.count + 2)))
    }

    private static func cells(_ line: String) -> [String] {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isSeparatorRow(_ line: String) -> Bool {
        line.allSatisfy { "|-: ".contains($0) }
    }
}
