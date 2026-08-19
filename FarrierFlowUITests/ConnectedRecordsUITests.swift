import XCTest

final class ConnectedRecordsUITests: XCTestCase {
    @MainActor
    func testConnectedRecordsPersistAcrossRelaunch() throws {
        let storeName = "ConnectedRecords-\(UUID().uuidString)"
        let clientName = "Avery Stone"
        let barnName = "North Field"
        let horseName = "Milo"
        let app = launch(storeName: storeName)

        openClients(in: app)
        let addClient = app.buttons["Add Client"].firstMatch
        XCTAssertTrue(addClient.waitForExistence(timeout: 10))
        addClient.tap()
        let clientNameField = app.textFields["client-name-field"]
        XCTAssertTrue(clientNameField.waitForExistence(timeout: 3))
        focusAndType(clientName, in: clientNameField)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["client-row-\(clientName)"].waitForExistence(timeout: 3))

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
        let barnNameField = app.textFields["barn-name-field"]
        XCTAssertTrue(barnNameField.waitForExistence(timeout: 3))
        focusAndType(barnName, in: barnNameField)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["barn-row-\(barnName)"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()

        app.staticTexts["client-row-\(clientName)"].tap()
        let addHorse = app.buttons["Add Horse"].firstMatch
        XCTAssertTrue(addHorse.waitForExistence(timeout: 10))
        addHorse.tap()
        let horseNameField = app.textFields["horse-name-field"]
        XCTAssertTrue(horseNameField.waitForExistence(timeout: 3))
        focusAndType(horseName, in: horseNameField)
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["horse-row-\(horseName)"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Today"].tap()
        let addAppointment = app.buttons["Schedule Appointment"].firstMatch
        XCTAssertTrue(addAppointment.waitForExistence(timeout: 10))
        addAppointment.tap()
        XCTAssertTrue(app.buttons["appointment-barn-picker"].waitForExistence(timeout: 3))
        app.buttons["appointment-barn-picker"].tap()
        let barnOptions = app.buttons.matching(identifier: barnName)
        XCTAssertTrue(barnOptions.firstMatch.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(barnOptions.count, 0)
        guard barnOptions.count > 0 else { return }
        barnOptions.element(boundBy: barnOptions.count - 1).tap()
        app.buttons["appointment-horse-\(horseName)"].tap()
        app.buttons["Save"].tap()
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.staticTexts["appointment-row-\(barnName)"].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.staticTexts["appointment-row-\(barnName)"].waitForExistence(timeout: 5))

        openClients(in: app)
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

    @MainActor
    private func openClients(in app: XCUIApplication) {
        for _ in 0..<2 {
            app.tabBars.buttons["Clients"].tap()
            if app.navigationBars["Clients"].waitForExistence(timeout: 2) {
                return
            }
        }
        XCTFail("Clients tab did not open")
    }

    @MainActor
    private func focusAndType(_ text: String, in element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        XCTAssertTrue(element.isHittable)
        element.tap()
        if !waitForKeyboardFocus(in: element) {
            element.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
            ).tap()
        }
        element.typeText(text)
    }

    @MainActor
    private func waitForKeyboardFocus(in element: XCUIElement) -> Bool {
        let focusExpectation = expectation(
            for: NSPredicate(format: "hasKeyboardFocus == true"),
            evaluatedWith: element
        )
        return XCTWaiter().wait(for: [focusExpectation], timeout: 2) == .completed
    }
}
