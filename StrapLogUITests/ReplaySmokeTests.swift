import XCTest

/// Drives the real UI against a replayed fixture: start, see beats arrive, mark, stop, see the export.
final class ReplaySmokeTests: XCTestCase {
    @MainActor
    func testRecordMarkStopInReplayMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()

        let link = app.staticTexts["linkStatus"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        XCTAssertTrue(link.waitForLabel(containing: "REPLAY", timeout: 5))

        let name = app.textFields["sessionName"]
        name.tap()
        name.typeText("SMOKE")
        app.buttons["startButton"].tap()

        XCTAssertTrue(app.staticTexts["beatCount"].waitForExistence(timeout: 10))
        let markerA = app.buttons["marker-a"]
        XCTAssertTrue(markerA.waitForExistence(timeout: 5))
        markerA.tap()
        sleep(2)
        app.buttons["stopButton"].tap()

        let snapshot = app.staticTexts["lastSnapshot"]
        XCTAssertTrue(snapshot.waitForExistence(timeout: 10))
        XCTAssertTrue(snapshot.label.contains("SMOKE.sqlite"))
    }
}

private extension XCUIElement {
    func waitForLabel(containing text: String, timeout: TimeInterval) -> Bool {
        let p = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: self)], timeout: timeout) == .completed
    }
}
