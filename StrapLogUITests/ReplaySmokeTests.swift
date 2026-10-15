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

        XCTAssertTrue(app.staticTexts["heartRate"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scroll(to: app.staticTexts["beatCount"]))
        let markerA = app.buttons["marker-a"]
        XCTAssertTrue(app.scroll(to: markerA))
        markerA.tap()
        let lastMarker = app.staticTexts["lastMarker"]
        XCTAssertTrue(lastMarker.waitForLabel(containing: "1 marker", timeout: 5))
        sleep(2)
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(app.scroll(to: stop))
        stop.tap()

        let snapshot = app.staticTexts["lastSnapshot"]
        XCTAssertTrue(snapshot.waitForExistence(timeout: 10))
        XCTAssertTrue(snapshot.label.contains("SMOKE.sqlite"))
    }

    @MainActor
    func testPacerStartsAndStops() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()
        app.buttons["startButton"].tap()

        let start = app.buttons["pacerStart"]
        XCTAssertTrue(app.scroll(to: start))
        start.tap()
        let instruction = app.staticTexts["pacerInstruction"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 5))
        XCTAssertTrue(instruction.label.hasPrefix("Breathe"))
        let stop = app.buttons["pacerStop"]
        XCTAssertTrue(stop.label.contains("6.0/min"))
        stop.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
    }

    @MainActor
    func testGuideOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()

        let help = app.buttons["helpButton"]
        XCTAssertTrue(help.waitForExistence(timeout: 10))
        help.tap()
        XCTAssertTrue(app.staticTexts["Understanding Your Numbers"].waitForExistence(timeout: 5))
        app.buttons["helpDone"].tap()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
    }
}

private extension XCUIApplication {
    /// Swipes up until `element` is on screen; the recording List only builds visible rows.
    func scroll(to element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return true }
            swipeUp()
        }
        return element.exists && element.isHittable
    }
}

private extension XCUIElement {
    func waitForLabel(containing text: String, timeout: TimeInterval) -> Bool {
        let p = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: self)], timeout: timeout) == .completed
    }
}
