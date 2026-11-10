import XCTest

final class StateContinuityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testHorseHeaderStaysAnchoredWhenExpandedAndCollapsed() {
        verifyHeader(largestText: false)
    }

    @MainActor
    func testHorseHeaderStaysAnchoredAtLargestText() {
        verifyHeader(largestText: true)
    }

    @MainActor
    private func verifyHeader(largestText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "StateContinuity-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "visit-workflow"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_NOW"] = "2026-10-28T12:00:00Z"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        defer { app.terminate() }
        let appointment = app.buttons["today-run-sheet-scheduled"]
        XCTAssertTrue(appointment.waitForExistence(timeout: 5))
        appointment.tap()
        let start = app.buttons["visit-start-action"]
        for _ in 0..<6 {
            if start.exists && start.isHittable && start.frame.maxY < app.frame.maxY - 100 { break }
            app.swipeUp()
        }
        start.tap()
        let header = app.buttons["visit-horse-toggle-Burger"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        revealHeader(header, in: app)
        XCTAssertEqual(header.value as? String, "Expanded")
        let name = app.staticTexts["visit-horse-name-Burger"]
        let status = app.staticTexts["visit-horse-status-Burger"]
        XCTAssertTrue(name.exists)
        XCTAssertTrue(status.exists)
        let headerY = header.frame.minY
        let nameY = name.frame.midY - header.frame.minY
        let statusY = status.frame.midY - header.frame.minY
        XCTAssertGreaterThanOrEqual(header.frame.height, 44)
        for index in 0..<4 {
            revealHeader(header, in: app)
            header.tap()
            let value = index.isMultiple(of: 2) ? "Collapsed" : "Expanded"
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: header)
            let result = XCTWaiter.wait(for: [changed], timeout: 3)
            if result != .completed { capture("Disclosure tap failed", in: app) }
            XCTAssertEqual(result, .completed, "Header: \(header.frame); \(header.value ?? "nil")")
            if !largestText { XCTAssertEqual(header.frame.minY, headerY, accuracy: 1) }
            XCTAssertEqual(name.frame.midY - header.frame.minY, nameY, accuracy: 1)
            XCTAssertEqual(status.frame.midY - header.frame.minY, statusY, accuracy: 1)
            XCTAssertEqual(status.label, "In Progress")
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Anchored native horse disclosure \(largestText ? "AX5" : "standard")"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func revealHeader(_ header: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            let top = app.navigationBars["Visit"].frame.maxY + 8
            let bottom = app.buttons["visit-save-progress"].frame.minY - 16
            if header.frame.minY >= top && header.frame.maxY <= bottom { return }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let upper = top + (bottom - top) * 0.35
            let lower = top + (bottom - top) * 0.65
            let down = header.frame.minY < top
            origin.withOffset(CGVector(dx: 200, dy: down ? upper : lower))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 200, dy: down ? lower : upper)))
        }
        capture("Header visibility", in: app)
        XCTFail("Header must be fully visible before measuring disclosure: \(header.frame)")
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
