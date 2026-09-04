import XCTest

final class BlockedMutationUITests: XCTestCase {
    @MainActor
    func testReferencedRecordsAreBlockedUntilAppointmentIsDeleted() throws {
        let clientName = "Blocked Client"
        let firstBarn = "Blocked Barn"
        let secondBarn = "Open Barn"
        let horseName = "Anchor"
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "BlockedMutation-\(UUID().uuidString)"
        app.launch()

        createClient(clientName, in: app)
        createBarn(firstBarn, in: app)
        createBarn(secondBarn, in: app)
        app.navigationBars.buttons["Clients"].tap()
        app.buttons["client-row-\(clientName)"].tap()
        createHorse(horseName, barnName: firstBarn, in: app)
        scheduleAppointment(horseName: horseName, barnName: firstBarn, in: app)

        app.tabBars.buttons["Clients"].tap()
        let horseRow = app.buttons["horse-row-\(horseName)"]
        XCTAssertTrue(
            horseRow.waitForExistence(timeout: 3)
        )
        guard tapUntilDestinationAppears(
            horseRow,
            destination: app.buttons["Edit"]
        ) else { return }

        guard tapUntilDestinationAppears(
            app.buttons["Edit"],
            destination: app.buttons["horse-barn-picker"]
        ) else { return }
        app.buttons["horse-barn-picker"].tap()
        app.buttons[secondBarn].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.alerts["Can’t Change Service Location"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["horse-detail-service-location"].exists
        )

        app.buttons["Delete"].tap()
        app.buttons["Delete Horse"].tap()
        XCTAssertTrue(app.alerts["Can’t Delete Horse"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()

        guard tapUntilDestinationAppears(
            app.navigationBars.buttons[clientName],
            destination: app.buttons["Actions"]
        ) else { return }
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete Client"].tap()
        XCTAssertTrue(app.alerts["Can’t Delete Client"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()

        guard tapUntilDestinationAppears(
            app.navigationBars.buttons["Clients"],
            destination: app.buttons["More"]
        ) else { return }
        guard tapUntilDestinationAppears(
            app.buttons["More"],
            destination: app.buttons["Service Locations"]
        ) else { return }
        guard tapUntilDestinationAppears(
            app.buttons["Service Locations"],
            destination: app.buttons["barn-row-\(firstBarn)"]
        ) else { return }
        guard tapUntilDestinationAppears(
            app.buttons["barn-row-\(firstBarn)"],
            destination: app.buttons["Actions"]
        ) else { return }
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete Service Location"].tap()
        XCTAssertTrue(
            app.alerts["Can’t Delete Service Location"].waitForExistence(timeout: 3)
        )
        app.alerts.buttons["OK"].tap()

        guard tapUntilDestinationAppears(
            app.tabBars.buttons["Schedule"],
            destination: app.navigationBars["Schedule"]
        ) else { return }
        XCTAssertTrue(app.buttons["appointment-row-\(firstBarn)"].waitForExistence(timeout: 3))
        guard tapUntilDestinationAppears(
            app.buttons["appointment-row-\(firstBarn)"],
            destination: app.buttons["Delete"]
        ) else { return }
        app.buttons["Delete"].tap()
        app.buttons["Delete Appointment"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["No scheduled appointments"].waitForExistence(timeout: 3)
        )
    }

    @MainActor
    private func createClient(_ name: String, in app: XCUIApplication) {
        let addClient = app.buttons["Add Client"].firstMatch
        for _ in 0..<2 where !app.navigationBars["Clients"].exists {
            app.tabBars.buttons["Clients"].tap()
            _ = app.navigationBars["Clients"].waitForExistence(timeout: 5)
        }
        XCTAssertTrue(app.navigationBars["Clients"].exists)
        XCTAssertTrue(addClient.waitForExistence(timeout: 10))
        guard addClient.exists else { return }
        let nameField = app.textFields["client-name-field"]
        for _ in 0..<2 where !nameField.exists {
            addClient.tap()
            _ = nameField.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(nameField.exists)
        guard nameField.exists else { return }
        XCTAssertTrue(app.navigationBars["New Client"].waitForExistence(timeout: 5))
        guard focusAndType(name, in: nameField) else { return }
        app.buttons["Save"].tap()
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
    private func createBarn(_ name: String, in app: XCUIApplication) {
        if !app.navigationBars["Service Locations"].exists {
            let more = app.buttons["More"].firstMatch
            XCTAssertTrue(more.waitForExistence(timeout: 10))
            let serviceLocations = app.buttons["Service Locations"].firstMatch
            for _ in 0..<2 where !serviceLocations.exists {
                more.tap()
                _ = serviceLocations.waitForExistence(timeout: 5)
            }
            XCTAssertTrue(serviceLocations.exists)
            for _ in 0..<2 where !app.navigationBars["Service Locations"].exists {
                serviceLocations.tap()
                _ = app.navigationBars["Service Locations"]
                    .waitForExistence(timeout: 5)
            }
        }
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 10))
        let addServiceLocation = app.buttons["Add Service Location"].firstMatch
        XCTAssertTrue(addServiceLocation.waitForExistence(timeout: 10))
        let nameField = app.textFields["barn-name-field"]
        for _ in 0..<2 where !nameField.exists {
            addServiceLocation.tap()
            _ = nameField.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(nameField.exists)
        guard nameField.exists else { return }
        XCTAssertTrue(
            app.navigationBars["New Service Location"].waitForExistence(timeout: 5)
        )
        guard focusAndType(name, in: nameField) else { return }
        app.buttons["Save"].tap()
    }

    @MainActor
    private func createHorse(
        _ name: String,
        barnName: String,
        in app: XCUIApplication
    ) {
        let addHorse = app.buttons["Add Horse"].firstMatch
        XCTAssertTrue(addHorse.waitForExistence(timeout: 3))
        addHorse.tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 5))
        guard focusAndType(name, in: app.textFields["horse-name-field"]) else { return }
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["Save"].tap()
    }

    @MainActor
    private func focusAndType(_ text: String, in element: XCUIElement) -> Bool {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        XCTAssertTrue(element.isHittable)
        for attempt in 0..<3 {
            if attempt == 0 {
                element.tap()
            } else {
                element.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
                ).tap()
            }
            if waitForKeyboardFocus(in: element) {
                element.typeText(text)
                return true
            }
        }
        XCTFail("Text field did not receive keyboard focus")
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

    @MainActor
    private func scheduleAppointment(
        horseName: String,
        barnName: String,
        in app: XCUIApplication
    ) {
        app.tabBars.buttons["Today"].tap()
        let addAppointment = app.buttons["Schedule Appointment"].firstMatch
        XCTAssertTrue(addAppointment.waitForExistence(timeout: 5))
        addAppointment.tap()
        app.buttons["appointment-barn-picker"].tap()
        let barnOptions = app.buttons.matching(identifier: barnName)
        XCTAssertTrue(barnOptions.firstMatch.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(barnOptions.count, 0)
        guard barnOptions.count > 0 else { return }
        barnOptions.element(boundBy: barnOptions.count - 1).tap()
        let horseButton = app.buttons["appointment-horse-\(horseName)"].firstMatch
        XCTAssertTrue(horseButton.waitForExistence(timeout: 5))
        horseButton.tap()
        app.buttons["Save"].tap()
    }
}
