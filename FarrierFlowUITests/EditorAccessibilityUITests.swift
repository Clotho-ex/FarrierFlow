import XCTest

final class EditorAccessibilityUITests: XCTestCase {
    @MainActor
    func testEditorsExposeAccessibleLabelsAndAppointmentPrerequisiteRecovery() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "EditorAccessibility-\(UUID().uuidString)"
        app.launch()

        app.tabBars.buttons["Clients"].tap()
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 10))
        let addClient = app.buttons["Add Client"].firstMatch
        XCTAssertTrue(addClient.waitForExistence(timeout: 10))
        addClient.tap()
        app.buttons["client-more-details"].tap()
        XCTAssertTrue(app.textViews["Client Notes"].waitForExistence(timeout: 3))
        app.textFields["client-name-field"].tap()
        app.textFields["client-name-field"].typeText("Accessible Client")
        app.buttons["Save"].tap()

        app.tabBars.buttons["Today"].tap()
        let addAppointment = app.buttons["Schedule Appointment"].firstMatch
        XCTAssertTrue(addAppointment.waitForExistence(timeout: 10))
        addAppointment.tap()
        let appointmentNotes = app.textViews["Appointment Notes"]
        app.buttons["appointment-more-details"].tap()
        XCTAssertTrue(appointmentNotes.waitForExistence(timeout: 3))
        appointmentNotes.tap()
        appointmentNotes.typeText("Keep this draft")
        let addServiceLocation = app.buttons["appointment-add-service-location"]
        XCTAssertTrue(addServiceLocation.waitForExistence(timeout: 3))
        addServiceLocation.tap()
        app.buttons["barn-more-details"].tap()
        XCTAssertTrue(app.textViews["Contact Notes"].waitForExistence(timeout: 3))
        app.textFields["barn-name-field"].tap()
        app.textFields["barn-name-field"].typeText("Accessible Barn")
        app.navigationBars["New Service Location"].buttons["Save"].tap()
        let barnPicker = app.buttons["appointment-barn-picker"]
        XCTAssertTrue(barnPicker.waitForExistence(timeout: 3))
        XCTAssertEqual(barnPicker.value as? String, "Accessible Barn")
        XCTAssertEqual(appointmentNotes.value as? String, "Keep this draft")
        XCTAssertTrue(
            app.staticTexts[
                "Add or move a horse to this service location before scheduling an appointment."
            ].waitForExistence(timeout: 3)
        )
        app.buttons["appointment-add-horse"].tap()
        app.buttons["horse-more-details"].tap()
        XCTAssertTrue(app.textViews["Safety Notes"].waitForExistence(timeout: 3))
        let horseName = app.textFields["horse-name-field"]
        XCTAssertTrue(horseName.waitForExistence(timeout: 3))
        horseName.tap()
        horseName.typeText("Appointment Horse")
        app.buttons["horse-client-picker"].tap()
        app.buttons["Accessible Client"].tap()
        app.navigationBars["New Horse"].buttons["Save"].tap()
        let selectedHorse = app.buttons["appointment-horse-Appointment Horse"]
        XCTAssertTrue(selectedHorse.waitForExistence(timeout: 3))
        XCTAssertEqual(selectedHorse.value as? String, "Selected")
        XCTAssertEqual(appointmentNotes.value as? String, "Keep this draft")
    }
}
