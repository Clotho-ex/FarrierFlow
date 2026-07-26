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
        app.buttons["Delete Appointment"].tap()
        XCTAssertTrue(
            app.staticTexts["No scheduled appointments"].waitForExistence(timeout: 3)
        )
    }

    @MainActor
    private func createClient(_ name: String, in app: XCUIApplication) {
        app.tabBars.buttons["Clients"].tap()
        app.buttons["Add Client"].firstMatch.tap()
        app.textFields["client-name-field"].tap()
        app.textFields["client-name-field"].typeText(name)
        app.buttons["Save"].tap()
    }

    @MainActor
    private func createBarn(_ name: String, in app: XCUIApplication) {
        if !app.navigationBars["Service Locations"].exists {
            app.buttons["More"].tap()
            app.buttons["Service Locations"].tap()
        }
        app.buttons["Add Service Location"].firstMatch.tap()
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
        app.buttons["Add Horse"].tap()
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
        app.buttons[barnName].tap()
        app.buttons["appointment-horse-\(horseName)"].tap()
        app.buttons["Save"].tap()
    }
}
