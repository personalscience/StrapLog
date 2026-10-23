import SwiftUI

/// The guide's contents, shown as a sheet from the toolbar: the introduction, one row per chapter,
/// a link out to the analysis skills, then the acknowledgements.
/// Every page carries Done, so a reader deep in a chapter can close the sheet without backing out.
struct HelpView: View {
    let book: GuideBook
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

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
                        NavigationLink(chapter.title, value: HelpRoute.chapter(title: chapter.title))
                            .accessibilityIdentifier("guideChapter-\(chapter.title)")
                    }
                }
                Section {
                    Link(destination: HelpRoute.analyzeURL) {
                        Label("Analyze with Claude skills", systemImage: "arrow.up.right.square")
                    }
                    .accessibilityIdentifier("analyzeLink")
                    Button(copied ? "Copied" : "Copy install command",
                           systemImage: copied ? "checkmark" : "doc.on.doc") {
                        UIPasteboard.general.string = HelpRoute.installCommands
                        copied = true
                    }
                    .accessibilityIdentifier("copyInstallCommand")
                } footer: {
                    Text("Open-source skills for Claude Code that read your recordings' files: overnight, resting, workout and threshold analyses.")
                }
                Section {
                    NavigationLink("Acknowledgements", value: HelpRoute.acknowledgements)
                    .accessibilityIdentifier("acknowledgements")
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: HelpRoute.self) { route in
                page(for: route).toolbar { done }
            }
            .toolbar { done }
        }
    }

    @ViewBuilder
    private func page(for route: HelpRoute) -> some View {
        switch route {
        case .chapter(let title):
            if let chapter = book.chapters.first(where: { $0.title == title }) {
                GuideChapterView(chapter: chapter)
            }
        case .acknowledgements:
            AcknowledgementsView(acknowledgements: Acknowledgement.all)
        case .license(let item):
            LicenseTextView(acknowledgement: item)
        }
    }

    private var done: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
                .accessibilityIdentifier("helpDone")
        }
    }
}
