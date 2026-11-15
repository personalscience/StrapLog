import XCTest

/// straplog-9fr.5: the RSA panel on the pacer screen, fed by the 3 min 6/min slice of the
/// 261115 calibration session (`-replay rsa-6`, real time: the pacer runs on wall time). The
/// pacer start is not aligned to the recording, so only swing and sync are checked, not the peak.
final class HeartFollowsBreathTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testPanelShowsTraceSwingAndSyncOnReplay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-replay", "rsa-6", "-speed", "1", "-freshDatabase"]
        app.launch()

        let toggle = app.buttons["pacerToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let rsa = app.switches["pacerRSA"]
        XCTAssertTrue(app.scroll(to: rsa), "the H10 replay offers Heart follows breath")
        if rsa.value as? String != "1" { rsa.switches.firstMatch.tap() }
        XCTAssertEqual(rsa.value as? String, "1")
        app.swipeDown()
        app.swipeDown()

        let start = app.buttons["pacerStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.buttons["pacerStop"].label.contains("6.0/min"), "the replay is the 6/min step")
        XCTAssertTrue(app.descendants(matching: .any)["rsaTrace"].waitForExistence(timeout: 10), "the trace starts with the first beats")

        // Four 10 s breaths, plus the beats that close the fourth.
        let swing = app.staticTexts["rsaSwing"]
        let fitted = NSPredicate(format: "label != %@", "— bpm")
        expectation(for: fitted, evaluatedWith: swing)
        waitForExpectations(timeout: 70)
        sleep(20)   // two more breaths for the screenshot
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "rsa-panel"
        shot.lifetime = .keepAlways
        add(shot)

        let bpm = try XCTUnwrap(Double(swing.label.replacingOccurrences(of: " bpm", with: "")))
        let sync = try XCTUnwrap(Double(app.staticTexts["rsaSync"].label.replacingOccurrences(of: "%", with: "")))
        XCTAssertTrue((6...14).contains(bpm), "fixture follow_6 fitted swing is 8.2–8.6 bpm, read \(bpm)")
        XCTAssertGreaterThan(sync, 50, "follow_6 sync is high, read \(sync)%")
        XCTAssertTrue(app.descendants(matching: .any)["rsaBars"].exists)
        XCTAssertTrue(app.staticTexts["rsaPeak"].exists)
    }
}
