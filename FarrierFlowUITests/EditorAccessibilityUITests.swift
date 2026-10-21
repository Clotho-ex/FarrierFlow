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
            destination: app.descendants(matching: .any)["client-notes-field"]
        ) else { return }
        guard focusAndType(
            "Accessible Client",
            in: app.textFields["client-name-field"]
        ) else { return }
        let dismissKeyboard = app.buttons["client-keyboard-done"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 3))
        dismissKeyboard.tap()
        let keyboardDismissed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.keyboards.firstMatch
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [keyboardDismissed], timeout: 3),
            .completed
        )
        XCTAssertTrue(app.navigationBars["New Client"].exists)
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
        dismissAppointmentKeyboard(in: app)
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
        guard revealElement(appointmentNotes, in: app) else { return }
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
        guard revealElement(appointmentNotes, in: app) else { return }
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
        guard revealElement(appointmentNotes, in: app) else { return }
        XCTAssertEqual(appointmentNotes.value as? String, "Keep this draft")
        let addService = app.buttons["appointment-add-service-Appointment Horse"]
        revealAddHorse(addService, in: app)
        guard tapUntilDestinationAppears(
            addService,
            destination: app.navigationBars["New Service"]
        ) else { return }
        guard focusAndType("Appointment Trim", in: app.textFields["service-name-field"]) else { return }
        guard focusAndType("50", in: app.textFields["service-price-field"]) else { return }
        app.navigationBars["New Service"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["appointment-service-Appointment Horse"].value as? String, "Appointment Trim")
        guard revealElement(appointmentNotes, in: app) else { return }
        XCTAssertEqual(appointmentNotes.value as? String, "Keep this draft")
    }

    @MainActor
    func testAppointmentKeyboardToolbarDismissesDurationAndNotesWithoutSaving() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "AppointmentKeyboard-\(UUID().uuidString)"
        app.launch()
        guard let today = openToday(in: app) else { return }
        guard tapUntilDestinationAppears(
            today.buttons["Schedule Appointment"],
            destination: app.navigationBars["New Appointment"]
        ) else { return }
        let duration = app.textFields["Expected Duration (minutes)"]
        guard tapUntilDestinationAppears(
            app.buttons["appointment-more-details"],
            destination: duration
        ) else { return }
        guard focusAndType("45", in: duration) else { return }
        let keyboardScreenshot = XCTAttachment(screenshot: app.screenshot())
        keyboardScreenshot.name = "Appointment keyboard Done toolbar"
        keyboardScreenshot.lifetime = .keepAlways
        add(keyboardScreenshot)
        dismissAppointmentKeyboard(in: app)
        XCTAssertEqual(duration.value as? String, "45")

        let notes = app.textViews["Appointment Notes"]
        guard focusAndType("Keep my appointment draft", in: notes) else { return }
        dismissAppointmentKeyboard(in: app)
        XCTAssertEqual(notes.value as? String, "Keep my appointment draft")
        XCTAssertTrue(app.navigationBars["New Appointment"].exists)
    }

    @MainActor
    func testAppointmentServiceSelectionPersistsAfterRelaunchAndSeedsVisit() throws {
        try verifyAppointmentServiceFlow(largeText: false)
    }

    @MainActor
    func testAppointmentServiceSelectionAtLargestTextSizeInDarkMode() throws {
        try verifyAppointmentServiceFlow(largeText: true)
    }

    @MainActor
    private func verifyAppointmentServiceFlow(largeText: Bool) throws {
        let app = XCUIApplication()
        if largeText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "AppointmentService-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "next-appointment"
        app.launch()
        guard openSchedule(in: app) else { return }
        guard tapUntilDestinationAppears(
            app.navigationBars["Schedule"].buttons["Schedule Appointment"],
            destination: app.navigationBars["New Appointment"]
        ) else { return }
        app.buttons["appointment-barn-picker"].tap()
        app.buttons["Next Appointment Service Location"].tap()
        let horse = app.buttons["appointment-horse-Atlas"]
        guard revealElement(horse, in: app) else { return }
        horse.tap()
        let service = app.buttons["appointment-service-Atlas"]
        guard revealElement(service, in: app) else { return }
        service.tap()
        app.buttons["Next Appointment Trim"].tap()
        XCTAssertEqual(service.value as? String, "Next Appointment Trim")
        let selectionScreenshot = XCTAttachment(screenshot: app.screenshot())
        selectionScreenshot.name = "New appointment service selection"
        selectionScreenshot.lifetime = .keepAlways
        add(selectionScreenshot)
        app.navigationBars["New Appointment"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        guard openSchedule(in: app) else { return }
        let row = app.buttons["appointment-row-Next Appointment Service Location"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        let planned = app.descendants(matching: .any)["appointment-planned-service-Atlas"].firstMatch
        guard revealElement(planned, in: app) else { return }
        XCTAssertTrue(planned.label.contains("Next Appointment Trim"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved appointment service"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let start = app.buttons["visit-start-action"]
        guard revealElement(start, in: app) else { return }
        start.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        XCTAssertTrue(revealElement(app.buttons["visit-work-item-Atlas-Next Appointment Trim"], in: app))
    }

    @MainActor
    private func dismissAppointmentKeyboard(in app: XCUIApplication) {
        let done = app.buttons["appointment-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        guard done.exists else { return }
        done.tap()
        let dismissed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter().wait(for: [dismissed], timeout: 3), .completed)
    }

    @MainActor
    private func revealAddHorse(_ button: XCUIElement, in app: XCUIApplication) {
        guard !button.isHittable else { return }
        let notes = app.textViews["Appointment Notes"]
        let scrollDown = notes.exists && notes.isHittable
        for _ in 0..<5 {
            if button.exists && button.isHittable { return }
            if scrollDown {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
    }

    @MainActor
    private func revealElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        XCTFail("Expected to reveal \(element.identifier)")
        return false
    }

    @MainActor
    private func openSchedule(in app: XCUIApplication) -> Bool {
        for _ in 0..<3 {
            app.tabBars.buttons["Schedule"].tap()
            if app.navigationBars["Schedule"].waitForExistence(timeout: 3) {
                return true
            }
        }
        XCTFail("Schedule tab did not open")
        return false
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
            if trigger.identifier.hasSuffix("-more-details") {
                trigger.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)
                ).tap()
                for _ in 0..<3 {
                    if destination.exists { return true }
                    XCUIApplication().swipeUp()
                }
            } else {
                trigger.tap()
            }
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
