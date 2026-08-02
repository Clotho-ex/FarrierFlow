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
        app.staticTexts["client-row-\(clientName)"].tap()
        createHorse(horseName, barnName: firstBarn, in: app)
        scheduleAppointment(horseName: horseName, barnName: firstBarn, in: app)

        app.tabBars.buttons["Clients"].tap()
        let horseRow = app.buttons["horse-row-\(horseName)"]
        XCTAssertTrue(
            horseRow.waitForExistence(timeout: 3)
        )
        horseRow.tap()

        app.buttons["Edit"].tap()
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

        app.navigationBars.buttons[clientName].tap()
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete Client"].tap()
        XCTAssertTrue(app.alerts["Can’t Delete Client"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()

        app.navigationBars.buttons["Clients"].tap()
        app.buttons["More"].tap()
        app.buttons["Service Locations"].tap()
        app.staticTexts["barn-row-\(firstBarn)"].tap()
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete Service Location"].tap()
        XCTAssertTrue(
            app.alerts["Can’t Delete Service Location"].waitForExistence(timeout: 3)
        )
        app.alerts.buttons["OK"].tap()

        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.staticTexts["appointment-row-\(firstBarn)"].waitForExistence(timeout: 3))
        app.staticTexts["appointment-row-\(firstBarn)"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete Appointment"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["No scheduled appointments"].waitForExistence(timeout: 3)
        )
    }

    @MainActor
    private func createClient(_ name: String, in app: XCUIApplication) {
        let addClient = app.buttons["Add Client"].firstMatch
        for _ in 0..<2 {
            app.tabBars.buttons["Clients"].tap()
            if addClient.waitForExistence(timeout: 5) {
                break
            }
        }
        XCTAssertTrue(addClient.waitForExistence(timeout: 5))
        guard addClient.exists else { return }
        addClient.tap()
        app.textFields["client-name-field"].tap()
        app.textFields["client-name-field"].typeText(name)
        app.buttons["Save"].tap()
    }

    @MainActor
    private func createBarn(_ name: String, in app: XCUIApplication) {
        if !app.navigationBars["Service Locations"].exists {
            let more = app.buttons["More"].firstMatch
            XCTAssertTrue(more.waitForExistence(timeout: 10))
            more.tap()
            let serviceLocations = app.buttons["Service Locations"].firstMatch
            XCTAssertTrue(serviceLocations.waitForExistence(timeout: 10))
            serviceLocations.tap()
        }
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 10))
        let addServiceLocation = app.buttons["Add Service Location"].firstMatch
        XCTAssertTrue(addServiceLocation.waitForExistence(timeout: 10))
        addServiceLocation.tap()
        app.textFields["barn-name-field"].tap()
        app.textFields["barn-name-field"].typeText(name)
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
        app.textFields["horse-name-field"].tap()
        app.textFields["horse-name-field"].typeText(name)
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["Save"].tap()
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
