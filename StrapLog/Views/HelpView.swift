import SwiftUI

/// The metrics guide, shown as a sheet from the toolbar.
struct HelpView: View {
    let blocks: [GuideBlock]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(blocks.indices, id: \.self) { GuideBlockView(block: blocks[$0]) }
                }
                .padding()
            }
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("helpDone")
                }
            }
        }
    }
}
