import SwiftUI

/// Copyright notices for the software inside StrapLog; each row pushes `HelpRoute.license`, the full text.
struct AcknowledgementsView: View {
    let acknowledgements: [Acknowledgement]

    var body: some View {
        List {
            Section {
                ForEach(acknowledgements) { item in
                    NavigationLink(value: HelpRoute.license(item)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.headline)
                            Text(item.copyright).font(.footnote).foregroundStyle(.secondary)
                            Text(item.license).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("acknowledgement-\(item.name)")
                }
            } footer: {
                Text("StrapLog uses this software under the licenses shown. StrapLog is not made, endorsed or supported by the authors of these packages or their owners.")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
