import SwiftUI

/// One chapter of the guide as a scrolling page.
struct GuideChapterView: View {
    let chapter: GuideChapter

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(chapter.blocks.indices, id: \.self) { GuideBlockView(block: chapter.blocks[$0]) }
            }
            .padding()
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
