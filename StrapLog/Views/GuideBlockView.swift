import SwiftUI

/// Renders one `GuideBlock`; inline Markdown goes through `AttributedString`.
struct GuideBlockView: View {
    let block: GuideBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .font(level == 1 ? .largeTitle.bold() : level == 2 ? .title2.bold() : .headline)
                .padding(.top, level == 1 ? 0 : 8)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(Self.inline(text))
        case .bullets(let items):
            list(items) { _ in "•" }
        case .numbered(let items):
            list(items) { "\($0 + 1)." }
        case .table(let header, let rows):
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow { ForEach(header.indices, id: \.self) { Text(Self.inline(header[$0])).bold() } }
                Divider()
                ForEach(rows.indices, id: \.self) { r in
                    GridRow { ForEach(rows[r].indices, id: \.self) { Text(Self.inline(rows[r][$0])) } }
                }
            }
            .font(.callout)
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        case .rule:
            Divider().padding(.vertical, 4)
        case .image(let name, let caption):
            VStack(spacing: 6) {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 440)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(Text(Self.inline(caption)))
                Text(Self.inline(caption))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private func list(_ items: [String], marker: @escaping (Int) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(marker(i)).monospacedDigit()
                    Text(Self.inline(items[i]))
                }
            }
        }
    }

    private static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}
