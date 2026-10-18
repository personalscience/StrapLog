import Foundation
import Testing
@testable import StrapLog

@Suite("Acknowledgement")
struct AcknowledgementTests {
    @Test("every acknowledged package ships its license text", arguments: Acknowledgement.all)
    func bundled(_ item: Acknowledgement) throws {
        let text = try #require(item.licenseText(in: Bundle(for: AppDelegate.self)))
        #expect(!text.isEmpty)
    }
}
