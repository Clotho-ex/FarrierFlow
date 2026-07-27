import XCTest

final class EditorAccessibilityUITests: XCTestCase {
    @MainActor
    func testMultilineEditorsExposeSpecificVoiceOverLabels() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "EditorAccessibility-\(UUID().uuidString)"
        app.launch()

        app.tabBars.buttons["Clients"].tap()
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 10))
        let addClient = app.buttons["Add Client"].firstMatch
        XCTAssertTrue(addClient.waitForExistence(timeout: 10))
        addClient.tap()
        XCTAssertTrue(app.textViews["Client Notes"].waitForExistence(timeout: 3))
        app.textFields["client-name-field"].tap()
        app.textFields["client-name-field"].typeText("Accessible Client")
        app.buttons["Save"].tap()

        let more = app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let serviceLocations = app.buttons["Service Locations"].firstMatch
        XCTAssertTrue(serviceLocations.waitForExistence(timeout: 10))
        serviceLocations.tap()
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 10))
        let addServiceLocation = app.buttons["Add Service Location"].firstMatch
        XCTAssertTrue(addServiceLocation.waitForExistence(timeout: 10))
        addServiceLocation.tap()
        XCTAssertTrue(app.textViews["Contact Notes"].waitForExistence(timeout: 3))
        app.textFields["barn-name-field"].tap()
        app.textFields["barn-name-field"].typeText("Accessible Barn")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()

        let clientRow = app.staticTexts["client-row-Accessible Client"]
        XCTAssertTrue(clientRow.waitForExistence(timeout: 3))
        clientRow.tap()
        let addHorse = app.buttons["Add Horse"].firstMatch
        XCTAssertTrue(addHorse.waitForExistence(timeout: 10))
        addHorse.tap()
        XCTAssertTrue(app.textViews["Safety Notes"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Today"].tap()
        let addAppointment = app.buttons["Schedule Appointment"].firstMatch
        XCTAssertTrue(addAppointment.waitForExistence(timeout: 10))
        addAppointment.tap()
        XCTAssertTrue(app.textViews["Appointment Notes"].waitForExistence(timeout: 3))
    }
}
