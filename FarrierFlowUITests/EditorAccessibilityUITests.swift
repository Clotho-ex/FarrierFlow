import XCTest

final class EditorAccessibilityUITests: XCTestCase {
    @MainActor
    func testMultilineEditorsExposeSpecificVoiceOverLabels() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "EditorAccessibility-\(UUID().uuidString)"
        app.launch()

        app.tabBars.buttons["Clients"].tap()
        app.buttons["Add Client"].firstMatch.tap()
        XCTAssertTrue(app.textViews["Client Notes"].waitForExistence(timeout: 3))
        app.textFields["client-name-field"].tap()
        app.textFields["client-name-field"].typeText("Accessible Client")
        app.buttons["Save"].tap()

        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Service Locations"].waitForExistence(timeout: 3))
        app.buttons["Service Locations"].tap()
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 3))
        app.buttons["Add Service Location"].firstMatch.tap()
        XCTAssertTrue(app.textViews["Contact Notes"].waitForExistence(timeout: 3))
        app.textFields["barn-name-field"].tap()
        app.textFields["barn-name-field"].typeText("Accessible Barn")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()

        let clientRow = app.staticTexts["client-row-Accessible Client"]
        XCTAssertTrue(clientRow.waitForExistence(timeout: 3))
        clientRow.tap()
        app.buttons["Add Horse"].tap()
        XCTAssertTrue(app.textViews["Safety Notes"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Today"].tap()
        app.buttons["Schedule Appointment"].firstMatch.tap()
        XCTAssertTrue(app.textViews["Appointment Notes"].waitForExistence(timeout: 3))
    }
}
