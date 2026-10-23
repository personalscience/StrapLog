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
        XCTAssertFalse(app.staticTexts["overnightLow"].exists, "only overnight presets show the lowest HR")
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
    func testSummaryCardDetailAndRename() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()
        app.segmentedControls["activityPicker"].buttons["Other"].tap()
        let name = app.textFields["sessionName"]
        name.tap()
        name.typeText("DETAIL")
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.staticTexts["heartRate"].waitForExistence(timeout: 10))
        let markerA = app.buttons["marker-a"]
        XCTAssertTrue(app.scroll(to: markerA))
        markerA.tap()
        sleep(5) // replay compresses receive times, so no α1 window closes; the summary still fills
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(app.scroll(to: stop))
        stop.tap()
        let confirm = app.buttons["confirmStop"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        let card = app.buttons["lastFinished"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "no summary card after Stop")
        XCTAssertTrue(card.label.contains("DETAIL"))
        card.tap()

        XCTAssertTrue(app.staticTexts["summaryBeats"].waitForExistence(timeout: 10))
        let markerRow = app.buttons["markerRow-0"]
        XCTAssertTrue(app.scroll(to: markerRow), "no marker row in the detail view")
        markerRow.tap()
        XCTAssertTrue(app.otherElements["trendChart"].exists, "chart gone after jumping to a marker")
        let detailName = app.textFields["detailName"]
        XCTAssertTrue(app.scroll(to: detailName))
        detailName.tap()
        detailName.clearAndType("RENAMED")
        app.buttons["detailSave"].tap()
        XCTAssertTrue(app.navigationBars["RENAMED"].waitForExistence(timeout: 10), "title did not follow the rename")
        XCTAssertTrue(app.scroll(to: app.buttons["detailShare"]), "no share link for the re-exported file")
    }

    @MainActor
    func testSleepRecordsWithPlanAndChart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()
        app.segmentedControls["activityPicker"].buttons["Sleep"].tap()
        XCTAssertTrue(app.switches["stopAtWake"].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()

        let plan = app.staticTexts["overnightPlan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        XCTAssertTrue(plan.label.lowercased().contains("stops"))
        XCTAssertTrue(app.segmentedControls["chartMetric"].exists, "sleep shows the live chart")
        XCTAssertTrue(app.staticTexts["overnightLow"].label.hasPrefix("Low "), "sleep shows the lowest HR so far")
        app.buttons["marker-lights_out"].tap()
        XCTAssertTrue(app.staticTexts["lastMarker"].waitForLabel(containing: "lights_out", timeout: 5))
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(app.scroll(to: stop))
        stop.tap()
        let confirm = app.buttons["confirmStop"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["lastFinished"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scroll(to: app.staticTexts["lastSnapshot"]), "the summary card pushes the export line down")
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
    func testPacerRunsBeforeAndDuringARecording() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "resting", "-speed", "20", "-freshDatabase"]
        app.launch()

        let toggle = app.buttons["pacerToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "the pacer is in the toolbar while idle")
        toggle.tap()
        let start = app.buttons["pacerStart"]
        XCTAssertTrue(app.scroll(to: start))
        start.tap()
        let instruction = app.staticTexts["pacerInstruction"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 5))
        XCTAssertTrue(instruction.label.hasPrefix("Breathe"))

        app.segmentedControls["activityPicker"].buttons["Other"].tap()
        let record = app.buttons["startButton"]
        XCTAssertTrue(app.scroll(to: record))
        record.tap()
        XCTAssertTrue(app.buttons["stopButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scroll(to: instruction), "the pacer keeps running into the recording")
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
        let chapter = app.buttons["guideChapter-Getting started"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        chapter.tap()
        XCTAssertTrue(app.staticTexts["Put the strap on"].waitForExistence(timeout: 5))
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.scroll(to: app.buttons["acknowledgements"]))
        app.buttons["acknowledgements"].tap()
        let polar = app.buttons["acknowledgement-Polar BLE SDK"]
        XCTAssertTrue(polar.waitForExistence(timeout: 5))
        polar.tap()
        XCTAssertTrue(app.navigationBars["Polar BLE SDK"].waitForExistence(timeout: 5))
        app.buttons["helpDone"].tap()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
    }
}
