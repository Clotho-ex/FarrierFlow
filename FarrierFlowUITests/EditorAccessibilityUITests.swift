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
        let clientMoreDetails = app.buttons["client-more-details"]
        guard tapUntilDestinationAppears(addClient, destination: clientMoreDetails) else { return }
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

        guard openSchedule(in: app) else { return }
        let addAppointment = app.navigationBars["Schedule"].buttons["Schedule Appointment"]
        XCTAssertTrue(addAppointment.waitForExistence(timeout: 10))
        guard tapUntilDestinationAppears(
            addAppointment,
            destination: app.navigationBars["New Appointment"]
        ) else { return }
        let appointmentNotes = app.textViews["Appointment Notes"]
        guard tapUntilDestinationAppears(
            app.buttons["appointment-additional-details"],
            destination: appointmentNotes
        ) else { return }
        appointmentNotes.tap()
        appointmentNotes.typeText("Keep this draft")
        dismissAppointmentKeyboard(in: app)
        guard revealElement(app.buttons["appointment-barn-picker"], in: app, towardTop: true) else { return }
        app.buttons["appointment-barn-picker"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let addServiceLocation = app.buttons["appointment-create-location"]
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
        XCTAssertFalse(app.buttons["appointment-create-horse"].exists)
        app.navigationBars["New Appointment"].buttons["Cancel"].tap()
        openClients(in: app)
        app.buttons["client-row-Accessible Client"].tap()
        for name in ["Appointment Horse", "Second Appointment Horse"] {
            let addHorse = app.buttons["Add Horse"]
            guard revealElement(addHorse, in: app) else { return }
            addHorse.tap()
            let horseName = app.textFields["horse-name-field"]
            guard focusAndType(name, in: horseName) else { return }
            app.buttons["horse-barn-picker"].tap()
            app.buttons["Accessible Barn"].tap()
            app.navigationBars["New Horse"].buttons["Save"].tap()
            XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 5))
        }
        guard openSchedule(in: app) else { return }
        app.navigationBars["Schedule"].buttons["Schedule Appointment"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
        app.buttons["appointment-barn-picker"].tap()
        app.buttons["Accessible Barn"].tap()
        for name in ["Appointment Horse", "Second Appointment Horse"] {
            let horse = app.buttons["appointment-horse-\(name)"]
            guard revealElement(horse, in: app) else { return }
            horse.tap()
            XCTAssertEqual(horse.value as? String, "Selected")
        }
        app.buttons["appointment-additional-details"].tap()
        guard revealElement(appointmentNotes, in: app) else { return }
        appointmentNotes.tap()
        appointmentNotes.typeText("Keep this draft")
        dismissAppointmentKeyboard(in: app)
        let serviceMenu = app.buttons["appointment-service-Appointment Horse"]
        guard revealElement(serviceMenu, in: app) else { return }
        serviceMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let addService = app.buttons["appointment-create-service"]
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
        guard openSchedule(in: app) else { return }
        guard tapUntilDestinationAppears(
            app.navigationBars["Schedule"].buttons["Schedule Appointment"],
            destination: app.navigationBars["New Appointment"]
        ) else { return }
        let duration = app.textFields["Expected Duration (minutes)"]
        guard tapUntilDestinationAppears(
            app.buttons["appointment-additional-details"],
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
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
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
        app.buttons["appointment-barn-picker"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Next Appointment Service Location"].tap()
        let horse = app.buttons["appointment-horse-Atlas"]
        guard revealElement(horse, in: app) else { return }
        horse.tap()
        XCTAssertFalse(app.textFields["appointment-duration"].exists)
        let service = app.buttons["appointment-service-Atlas"]
        guard revealElement(service, in: app) else { return }
        service.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
        guard revealElement(start, in: app, towardTop: true) else { return }
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
    private func revealElement(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) -> Bool {
        for _ in 0..<8 {
            let top = app.navigationBars.allElementsBoundByIndex
                .filter(\.isHittable).map { $0.frame.maxY }.max() ?? app.frame.minY + 100
            let frame = element.exists ? element.frame : .zero
            if element.exists, frame.width > 0,
               frame.midY > top + 8, frame.midY < app.frame.maxY - 20 {
                return true
            }
            let surface = app.collectionViews.allElementsBoundByIndex.last(where: \.isHittable) ?? app
            let down = towardTop || (element.exists && frame.midY <= top + 8)
            // Use the form gutter so an embedded notes editor cannot consume the drag.
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: down ? 0.2 : 0.8))
            let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: down ? 0.8 : 0.2))
            start.press(forDuration: 0.01, thenDragTo: end)
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
        guard revealElement(element, in: XCUIApplication(), towardTop: element.identifier.hasSuffix("-name-field")) else { return false }
        for attempt in 0..<4 {
            if attempt == 0 {
                element.tap()
            } else {
                element.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: [0.5, 0.75, 0.85, 0.65][attempt])
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
