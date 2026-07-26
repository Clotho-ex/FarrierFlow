import XCTest

final class ConnectedRecordsUITests: XCTestCase {
    @MainActor
    func testConnectedRecordsPersistAcrossRelaunch() throws {
        let storeName = "ConnectedRecords-\(UUID().uuidString)"
        let clientName = "Avery Stone"
        let barnName = "North Field"
        let horseName = "Milo"
        let app = launch(storeName: storeName)

        app.tabBars.buttons["Clients"].tap()
        app.buttons["Add Client"].firstMatch.tap()
        let clientNameField = app.textFields["client-name-field"]
        XCTAssertTrue(clientNameField.waitForExistence(timeout: 3))
        clientNameField.tap()
        clientNameField.typeText(clientName)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["client-row-\(clientName)"].waitForExistence(timeout: 3))

        app.buttons["More"].tap()
        app.buttons["Service Locations"].tap()
        app.buttons["Add Service Location"].firstMatch.tap()
        let barnNameField = app.textFields["barn-name-field"]
        XCTAssertTrue(barnNameField.waitForExistence(timeout: 3))
        barnNameField.tap()
        barnNameField.typeText(barnName)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["barn-row-\(barnName)"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()

        app.staticTexts["client-row-\(clientName)"].tap()
        app.buttons["Add Horse"].tap()
        let horseNameField = app.textFields["horse-name-field"]
        XCTAssertTrue(horseNameField.waitForExistence(timeout: 3))
        horseNameField.tap()
        horseNameField.typeText(horseName)
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["horse-row-\(horseName)"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Today"].tap()
        app.buttons["Schedule Appointment"].firstMatch.tap()
        XCTAssertTrue(app.buttons["appointment-barn-picker"].waitForExistence(timeout: 3))
        app.buttons["appointment-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["appointment-horse-\(horseName)"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["appointment-row-\(barnName)"].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["appointment-row-\(barnName)"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Clients"].tap()
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 3))
        app.staticTexts["client-row-\(clientName)"].tap()
        XCTAssertTrue(app.staticTexts["horse-row-\(horseName)"].waitForExistence(timeout: 3))
        app.staticTexts["horse-row-\(horseName)"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["horse-detail-client"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["horse-detail-service-location"].exists
        )
    }

    @MainActor
    private func launch(storeName: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launch()
        return app
    }
}
