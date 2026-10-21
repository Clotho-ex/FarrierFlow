import XCTest

final class ClientListHierarchyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCountsAndLongNamesPreserveTheListInLightAndDarkMode() {
        let app = launch()
        defer { app.terminate() }
        editSeededClient(name: "Arthur Morgan", in: app)
        let arthur = app.buttons["client-row-Arthur Morgan"]
        XCTAssertTrue(arthur.waitForExistence(timeout: 3))
        capture(app, name: "Clients — Light, standard text")
        print("CLIENT_ROW_FRAME standard=\(arthur.frame)")
        XCTAssertTrue(arthur.label.contains("3 horses"))
        XCTAssertTrue(arthur.label.contains("+13625849"))

        app.navigationBars["Clients"].buttons["Add Client"].tap()
        fillName(longName, in: app)
        app.buttons["client-more-details"].tap()
        fillPhone(in: app)
        app.navigationBars["New Client"].buttons["Save"].tap()
        let longRow = app.buttons["client-row-\(longName)"]
        XCTAssertTrue(longRow.waitForExistence(timeout: 3))
        XCTAssertTrue(longRow.label.contains("0 horses"))
        capture(app, name: "Clients — Light, long name")

        app.terminate()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        app.launch()
        app.selectFarrierFlowTab("Clients")
        XCTAssertTrue(arthur.waitForExistence(timeout: 3))
        XCTAssertTrue(arthur.label.contains("3 horses"))
        XCTAssertTrue(longRow.label.contains("0 horses"))
        capture(app, name: "Clients — Dark, standard text")
        arthur.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLongNameAndCountRemainReadableAtLargestAccessibilitySize() {
        let app = launch(accessibility: true)
        defer { app.terminate() }
        editSeededClient(name: longName, in: app)
        let row = app.buttons["client-row-\(longName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.label.contains(longName))
        XCTAssertTrue(row.label.contains("+13625849"))
        XCTAssertTrue(row.label.contains("3 horses"))
        capture(app, name: "Clients — Dark, largest accessibility text")
        row.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
    }

    private var longName: String {
        "Alexandria Montgomery-Wellington and Family"
    }

    @MainActor
    private func launch(accessibility: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "ClientHierarchy-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "next-appointment"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = accessibility ? "dark" : "light"
        if accessibility {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        app.selectFarrierFlowTab("Clients")
        return app
    }

    @MainActor
    private func editSeededClient(name: String, in app: XCUIApplication) {
        let row = app.buttons["client-row-Next Appointment Client"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        app.navigationBars["Client"].buttons["Actions"].tap()
        app.buttons["Edit"].tap()
        fillName(name, in: app)
        fillPhone(in: app)
        app.navigationBars["Edit Client"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Edit Client"].waitForNonExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()
    }

    @MainActor
    private func fillName(_ name: String, in app: XCUIApplication) {
        replaceText(name, in: app.textFields["client-name-field"], app: app)
        dismissKeyboard(in: app)
    }

    @MainActor
    private func fillPhone(in app: XCUIApplication) {
        replaceText("+13625849", in: app.textFields["client-phone-field"], app: app)
        dismissKeyboard(in: app)
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["client-keyboard-done"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    @MainActor
    private func replaceText(_ text: String, in field: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let original = (field.value as? String) ?? ""
        for attempt in 0..<3 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: attempt == 0 ? 0.5 : 0.85)).tap()
            let focus = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field
            )
            if XCTWaiter.wait(for: [focus], timeout: 2) == .completed {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count))
                field.typeText(text)
                return
            }
        }
        XCTFail("Expected input field to receive keyboard focus")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
