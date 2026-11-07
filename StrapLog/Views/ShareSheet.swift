import SwiftUI
import UIKit

/// The system share sheet for one file, for sharing that starts from code rather than a tap on
/// a `ShareLink` (the export the user asked to share as they stopped).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onDone() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
