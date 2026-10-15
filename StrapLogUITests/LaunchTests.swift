import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testAppLaunchesAndShowsVersion() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["versionLabel"].waitForExistence(timeout: 10))
    }
}
