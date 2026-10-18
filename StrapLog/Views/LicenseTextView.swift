import SwiftUI

/// One package's license, verbatim and selectable.
struct LicenseTextView: View {
    let acknowledgement: Acknowledgement

    var body: some View {
        ScrollView {
            Text(acknowledgement.licenseText(in: .main) ?? "The license text is missing from this build.")
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(acknowledgement.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
