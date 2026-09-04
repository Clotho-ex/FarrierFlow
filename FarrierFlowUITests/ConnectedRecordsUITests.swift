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
        let clientNameField = app.textFields["client-name-field"]
        guard tapUntilDestinationAppears(
            addClient,
            destination: clientNameField
        ) else { return }
        focusAndType(clientName, in: clientNameField)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["client-row-\(clientName)"].waitForExistence(timeout: 3))

        let more = app.buttons["More"].firstMatch
        let serviceLocations = app.buttons["Service Locations"].firstMatch
        guard tapUntilDestinationAppears(
            more,
            destination: serviceLocations
        ) else { return }
        guard tapUntilDestinationAppears(
            serviceLocations,
            destination: app.navigationBars["Service Locations"]
        ) else { return }
        let addServiceLocation = app.buttons["Add Service Location"].firstMatch
        let barnNameField = app.textFields["barn-name-field"]
        guard tapUntilDestinationAppears(
            addServiceLocation,
            destination: barnNameField
        ) else { return }
        focusAndType(barnName, in: barnNameField)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["barn-row-\(barnName)"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()

        guard tapUntilDestinationAppears(
            app.buttons["client-row-\(clientName)"],
            destination: app.buttons["Add Horse"].firstMatch
        ) else { return }
        let addHorse = app.buttons["Add Horse"].firstMatch
        let horseNameField = app.textFields["horse-name-field"]
        guard tapUntilDestinationAppears(
            addHorse,
            destination: horseNameField
        ) else { return }
        focusAndType(horseName, in: horseNameField)
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["horse-row-\(horseName)"].waitForExistence(timeout: 3))

        let today = app.tabBars.buttons["Today"]
        for _ in 0..<2 where !app.navigationBars["Today"].exists {
            today.tap()
            _ = app.navigationBars["Today"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.navigationBars["Today"].exists)
        let addAppointment = app.buttons["Schedule Appointment"].firstMatch
        guard tapUntilDestinationAppears(
            addAppointment,
            destination: app.buttons["appointment-barn-picker"]
        ) else { return }
        app.buttons["appointment-barn-picker"].tap()
        let barnOptions = app.buttons.matching(identifier: barnName)
        XCTAssertTrue(barnOptions.firstMatch.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(barnOptions.count, 0)
        guard barnOptions.count > 0 else { return }
        barnOptions.element(boundBy: barnOptions.count - 1).tap()
        app.buttons["appointment-horse-\(horseName)"].tap()
        app.buttons["Save"].tap()
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.buttons["appointment-row-\(barnName)"].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        let schedule = app.tabBars.buttons["Schedule"]
        for _ in 0..<2 where !app.navigationBars["Schedule"].exists {
            schedule.tap()
            _ = app.navigationBars["Schedule"].waitForExistence(timeout: 5)
        }
        XCTAssertTrue(app.navigationBars["Schedule"].exists)
        XCTAssertTrue(
            app.buttons["appointment-row-\(barnName)"].waitForExistence(timeout: 10)
        )

        openClients(in: app)
        app.buttons["client-row-\(clientName)"].tap()
        XCTAssertTrue(app.buttons["horse-row-\(horseName)"].waitForExistence(timeout: 3))
        app.buttons["horse-row-\(horseName)"].tap()
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
    private func tapUntilDestinationAppears(
        _ action: XCUIElement,
        destination: XCUIElement
    ) -> Bool {
        for _ in 0..<2 {
            guard action.waitForExistence(timeout: 5) else { continue }
            action.tap()
            if destination.waitForExistence(timeout: 5) {
                return true
            }
        }
        XCTFail("Expected action to open its destination")
        return false
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
