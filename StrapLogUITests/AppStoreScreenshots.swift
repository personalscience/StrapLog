import XCTest

/// Captures the App Store screenshots from a real-time replay (α1 needs real receive times).
/// Takes about four minutes, so it runs only when asked:
/// `TEST_RUNNER_STRAPLOG_SCREENSHOTS=1 tools/screenshots.sh` exports the PNGs.
final class AppStoreScreenshots: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STRAPLOG_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_STRAPLOG_SCREENSHOTS=1 to capture screenshots")
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureListingScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "1", "-freshDatabase"]
        app.launch()

        app.segmentedControls["activityPicker"].buttons["Other"].tap()
        let name = app.textFields["sessionName"]
        name.tap()
        name.typeText("Morning check")
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.staticTexts["heartRate"].waitForExistence(timeout: 10))

        addNote("seated rest", in: app)
        XCTAssertTrue(app.staticTexts["alpha1"].waitForLabel(containing: ".", timeout: 200), "no α1 yet")
        sleep(25) // a second α1 point, so the α1 chart draws a line
        app.segmentedControls["chartMetric"].buttons["α1"].tap()
        snap("02-alpha1", app)
        app.segmentedControls["chartMetric"].buttons["HR"].tap()
        snap("01-recording", app)

        addNote("slow breathing", in: app)
        let toggle = app.buttons["pacerToggle"]
        XCTAssertTrue(app.scroll(to: toggle))
        toggle.tap()
        let start = app.buttons["pacerStart"]
        XCTAssertTrue(app.scroll(to: start))
        start.tap()
        XCTAssertTrue(app.staticTexts["pacerInstruction"].waitForExistence(timeout: 5))
        sleep(3)
        snap("04-pacer", app)
        app.buttons["pacerStop"].tap()

        let stop = app.buttons["stopButton"]
        XCTAssertTrue(app.scroll(to: stop))
        stop.tap()
        app.buttons["confirmStop"].firstMatch.tap()
        let card = app.buttons["lastFinished"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        snap("05-home", app)
        card.tap()
        XCTAssertTrue(app.staticTexts["summaryBeats"].waitForExistence(timeout: 10))
        snap("03-detail", app)
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["helpButton"].tap()
        let chapter = app.buttons["guideChapter-DFA α1 and training zones"]
        XCTAssertTrue(app.scroll(to: chapter))
        chapter.tap()
        sleep(1)
        snap("06-guide", app)
    }

    @MainActor
    private func addNote(_ text: String, in app: XCUIApplication) {
        let add = app.buttons["markerAdd"]
        XCTAssertTrue(app.scroll(to: add))
        add.tap()
        let note = app.textFields["markerNote"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.typeText(text)
        app.buttons["markerNoteAdd"].tap()
        XCTAssertTrue(app.staticTexts["lastMarker"].waitForLabel(containing: text, timeout: 5))
        app.swipeDown() // back to the top: numbers and chart
    }

    @MainActor
    private func snap(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
