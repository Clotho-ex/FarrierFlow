import XCTest

final class RecordTitleUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testBusinessRecordTitlesStayCenteredWhileScrolling() {
        verifyTitles(largestText: false)
    }

    @MainActor
    func testBusinessRecordTitlesStayCenteredAtLargestTextInDarkMode() {
        verifyTitles(largestText: true)
    }

    @MainActor
    private func verifyTitles(largestText: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "RecordTitles-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "invoice-ready"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText { app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        for title in ["Service Locations", "Services", "Recorded Work", "Invoices"] {
            app.openBusinessRoot()
            let row = title == "Recorded Work" ? app.buttons["business-recorded-work"] : app.buttons[title]
            for _ in 0..<8 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.isHittable)
            row.tap()
            let bar = app.navigationBars[title]
            XCTAssertTrue(bar.waitForExistence(timeout: 3))
            let label = bar.staticTexts[title]
            XCTAssertTrue(label.exists)
            let initial = label.frame
            // Native searchable pages include the search field in the bar bounds.
            XCTAssertEqual(initial.midY, bar.frame.minY + 22, accuracy: 3)
            XCTAssertEqual(initial.midX, app.frame.midX, accuracy: 2)
            app.swipeUp()
            XCTAssertEqual(label.frame.midY, initial.midY, accuracy: 2)
            XCTAssertEqual(label.frame.midX, initial.midX, accuracy: 2)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(title) fixed title \(largestText ? "AX dark" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
