import SwiftUI

/// The guide's contents, shown as a sheet from the toolbar: the introduction, then one row per chapter.
/// Every page carries Done, so a reader deep in a chapter can close the sheet without backing out.
struct HelpView: View {
    let book: GuideBook
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(book.intro.indices, id: \.self) { GuideBlockView(block: book.intro[$0]) }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    ForEach(book.chapters) { chapter in
                        NavigationLink(chapter.title, value: chapter.title)
                            .accessibilityIdentifier("guideChapter-\(chapter.title)")
                    }
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { title in
                if let chapter = book.chapters.first(where: { $0.title == title }) {
                    GuideChapterView(chapter: chapter).toolbar { done }
                }
            }
            .toolbar { done }
        }
    }

    private var done: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
                .accessibilityIdentifier("helpDone")
        }
    }
}
