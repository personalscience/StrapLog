import XCTest

/// Drives the real UI against a replayed fixture: start, see beats arrive, mark, stop, see the export.
final class ReplaySmokeTests: XCTestCase {
    @MainActor
    func testRecordMarkStopInReplayMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()

        let heart = app.buttons["heartLink"]
        XCTAssertTrue(heart.waitForExistence(timeout: 10))
        XCTAssertTrue(heart.waitForLabel(containing: "REPLAY", timeout: 5))

        app.segmentedControls["activityPicker"].buttons["Other"].tap()
        let name = app.textFields["sessionName"]
        name.tap()
        name.typeText("SMOKE")
        app.buttons["startButton"].tap()

        XCTAssertTrue(app.staticTexts["heartRate"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.segmentedControls["chartMetric"].waitForExistence(timeout: 5))
        heart.tap()
        let done = app.buttons["deviceDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "device sheet did not open")
        XCTAssertTrue(app.scroll(to: app.staticTexts["beatCount"]))
        done.tap()
        let markerA = app.buttons["marker-a"]
        XCTAssertTrue(app.scroll(to: markerA))
        markerA.tap()
        let lastMarker = app.staticTexts["lastMarker"]
        XCTAssertTrue(lastMarker.waitForLabel(containing: "1 marker", timeout: 5))
        sleep(2)
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(app.scroll(to: stop))
        stop.tap()
        let confirm = app.buttons["confirmStop"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        let snapshot = app.staticTexts["lastSnapshot"]
        XCTAssertTrue(snapshot.waitForExistence(timeout: 10))
        XCTAssertTrue(snapshot.label.contains("SMOKE.sqlite"))
    }

    @MainActor
    func testSleepRecordsOnADarkScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()
        app.segmentedControls["activityPicker"].buttons["Sleep"].tap()
        XCTAssertTrue(app.switches["stopAtWake"].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()

        let plan = app.staticTexts["overnightPlan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        XCTAssertTrue(plan.label.lowercased().contains("stops"))
        XCTAssertFalse(app.segmentedControls["chartMetric"].exists, "no chart overnight")
        app.buttons["marker-lights_out"].tap()
        XCTAssertTrue(app.staticTexts["lastMarker"].waitForLabel(containing: "lights_out", timeout: 5))
        app.buttons["stopButton"].tap()
        let confirm = app.buttons["confirmStop"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["lastSnapshot"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testNoteSheetAndMarkerEditor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()
        app.segmentedControls["activityPicker"].buttons["Other"].tap()
        app.buttons["startButton"].tap()

        let add = app.buttons["markerAdd"]
        XCTAssertTrue(app.scroll(to: add))
        add.tap()
        let note = app.textFields["markerNote"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.typeText("felt dizzy")
        app.buttons["markerNoteAdd"].tap()
        let lastMarker = app.staticTexts["lastMarker"]
        XCTAssertTrue(lastMarker.waitForLabel(containing: "felt dizzy", timeout: 5))

        add.tap()
        let recent = app.buttons["recentNote-felt dizzy"]
        XCTAssertTrue(recent.waitForExistence(timeout: 5), "a used note is offered again")
        recent.tap()
        XCTAssertTrue(lastMarker.waitForLabel(containing: "2 markers", timeout: 5))

        app.buttons["marker-a"].press(forDuration: 1)
        let edit = app.buttons["Edit markers…"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Other markers"].waitForExistence(timeout: 5), "editor did not open")
        let label = app.textFields["newMarkerLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText("squat")
        app.buttons["saveMarkers"].tap()
        let squat = app.buttons["marker-squat"]
        XCTAssertTrue(squat.waitForExistence(timeout: 5), "the edited bar shows at once")
        squat.tap()
        XCTAssertTrue(lastMarker.waitForLabel(containing: "squat", timeout: 5))
    }

    @MainActor
    func testPacerStartsAndStops() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()
        app.segmentedControls["activityPicker"].buttons["Other"].tap()
        app.buttons["startButton"].tap()

        let toggle = app.buttons["pacerToggle"]
        XCTAssertTrue(app.scroll(to: toggle))
        toggle.tap()
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
    func testLandscapeKeepsNumbersChartAndMarkers() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()
        app.segmentedControls["activityPicker"].buttons["Other"].tap()
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.staticTexts["heartRate"].waitForExistence(timeout: 10))

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let heartRate = app.staticTexts["heartRate"]
        let chart = app.otherElements["trendChart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        sleep(1) // let the rotation settle before comparing frames
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways // the landscape layout is checked by eye too
        add(shot)
        XCTAssertTrue(heartRate.isHittable && chart.isHittable, "numbers and chart share the first screen")
        XCTAssertLessThan(heartRate.frame.maxX, chart.frame.minX, "numbers sit left of the chart")
        XCTAssertTrue(app.scroll(to: app.buttons["marker-a"]))
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
    /// Swipes up until `element` is on screen.
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
