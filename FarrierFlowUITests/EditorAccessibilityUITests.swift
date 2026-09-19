import XCTest

final class EditorAccessibilityUITests: XCTestCase {
    @MainActor
    func testEditorsExposeAccessibleLabelsAndAppointmentPrerequisiteRecovery() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "EditorAccessibility-\(UUID().uuidString)"
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        openClients(in: app)
        let addClient = app.navigationBars["Clients"].buttons["Add Client"]
        XCTAssertTrue(addClient.waitForExistence(timeout: 10))
        addClient.tap()
        let clientMoreDetails = app.buttons["client-more-details"]
        XCTAssertTrue(clientMoreDetails.waitForExistence(timeout: 3))
        guard tapUntilDestinationAppears(
            clientMoreDetails,
            destination: app.textViews["Client Notes"]
        ) else { return }
        guard focusAndType(
            "Accessible Client",
            in: app.textFields["client-name-field"]
        ) else { return }
        app.buttons["Save"].tap()

        guard let todayNavigationBar = openToday(in: app) else { return }
        let addAppointment = todayNavigationBar.buttons["Schedule Appointment"]
        XCTAssertTrue(addAppointment.waitForExistence(timeout: 10))
        guard tapUntilDestinationAppears(
            addAppointment,
            destination: app.navigationBars["New Appointment"]
        ) else { return }
        let appointmentNotes = app.textViews["Appointment Notes"]
        guard tapUntilDestinationAppears(
            app.buttons["appointment-more-details"],
            destination: appointmentNotes
        ) else { return }
        appointmentNotes.tap()
        appointmentNotes.typeText("Keep this draft")
        let addServiceLocation = app.buttons["appointment-add-service-location"]
        XCTAssertTrue(addServiceLocation.waitForExistence(timeout: 3))
        guard tapUntilDestinationAppears(
            addServiceLocation,
            destination: app.textFields["barn-name-field"]
        ) else { return }
        guard tapUntilDestinationAppears(
            app.buttons["barn-more-details"],
            destination: app.textViews["Contact Notes"]
        ) else { return }
        guard focusAndType(
            "Accessible Barn",
            in: app.textFields["barn-name-field"]
        ) else { return }
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
        let horseName = app.textFields["horse-name-field"]
        let addHorse = app.buttons["appointment-add-horse"]
        revealAddHorse(addHorse, in: app)
        guard tapUntilDestinationAppears(
            addHorse,
            destination: horseName
        ) else { return }
        guard tapUntilDestinationAppears(
            app.buttons["horse-more-details"],
            destination: app.textViews["Additional Notes"]
        ) else { return }
        XCTAssertTrue(horseName.waitForExistence(timeout: 3))
        app.buttons["horse-client-picker"].tap()
        app.buttons["Accessible Client"].tap()
        XCTAssertTrue(app.buttons["horse-client-picker"].label.contains("Accessible Client"))
        guard focusAndType("Appointment Horse", in: horseName) else { return }
        app.navigationBars["New Horse"].buttons["Save"].tap()
        let selectedHorse = app.buttons["appointment-horse-Appointment Horse"]
        XCTAssertTrue(selectedHorse.waitForExistence(timeout: 3))
        XCTAssertEqual(selectedHorse.value as? String, "Selected")
        XCTAssertEqual(appointmentNotes.value as? String, "Keep this draft")

        let addAnotherHorse = app.buttons["appointment-add-horse"]
        guard addAnotherHorse.waitForExistence(timeout: 3) else {
            XCTFail("Add Horse should remain available after creating the first horse")
            return
        }
        let secondHorseName = app.textFields["horse-name-field"]
        revealAddHorse(addAnotherHorse, in: app)
        guard tapUntilDestinationAppears(
            addAnotherHorse,
            destination: secondHorseName
        ) else { return }
        app.buttons["horse-client-picker"].tap()
        app.buttons["Accessible Client"].tap()
        XCTAssertTrue(app.buttons["horse-client-picker"].label.contains("Accessible Client"))
        guard focusAndType("Second Appointment Horse", in: secondHorseName) else {
            return
        }
        app.navigationBars["New Horse"].buttons["Save"].tap()

        let secondSelectedHorse = app.buttons[
            "appointment-horse-Second Appointment Horse"
        ]
        XCTAssertTrue(secondSelectedHorse.waitForExistence(timeout: 3))
        XCTAssertEqual(selectedHorse.value as? String, "Selected")
        XCTAssertEqual(secondSelectedHorse.value as? String, "Selected")
        XCTAssertEqual(appointmentNotes.value as? String, "Keep this draft")
    }

    @MainActor
    private func revealAddHorse(_ button: XCUIElement, in app: XCUIApplication) {
        guard !button.isHittable else { return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.6))
            .press(
                forDuration: 0.05,
                thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.95, dy: 0.2)
                )
            )
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
    private func openToday(in app: XCUIApplication) -> XCUIElement? {
        let navigationBar = app.navigationBars["Today"]
        for _ in 0..<3 {
            app.tabBars.buttons["Today"].tap()
            if navigationBar.waitForExistence(timeout: 3) {
                return navigationBar
            }
        }
        XCTFail("Today tab did not open")
        return nil
    }

    @MainActor
    private func tapUntilDestinationAppears(
        _ trigger: XCUIElement,
        destination: XCUIElement
    ) -> Bool {
        for _ in 0..<3 {
            if destination.exists || destination.waitForExistence(timeout: 1) {
                return true
            }
            guard trigger.waitForExistence(timeout: 3), trigger.isHittable else {
                continue
            }
            trigger.tap()
        }
        if destination.waitForExistence(timeout: 3) {
            return true
        }
        XCTFail("Expected \(destination.identifier) after tapping \(trigger.identifier)")
        return false
    }

    @MainActor
    private func focusAndType(_ text: String, in element: XCUIElement) -> Bool {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        guard element.exists else { return false }
        XCTAssertTrue(element.isHittable)
        for attempt in 0..<4 {
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
        XCTFail("Expected \(element.identifier) to receive keyboard focus")
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
