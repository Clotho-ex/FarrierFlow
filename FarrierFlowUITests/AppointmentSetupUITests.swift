import XCTest

final class AppointmentSetupUITests: XCTestCase {
    @MainActor
    func testInitialServiceSetupPersistsAndIsManagedFromMyBusiness() {
        verifyInitialServices(largestText: false)
    }

    @MainActor
    func testInitialServiceSetupSupportsLargestText() {
        verifyInitialServices(largestText: true)
    }

    @MainActor
    func testInitialServicesDoNotBypassSubscription() {
        verifyInitialServices(largestText: false, readOnly: true)
    }

    @MainActor
    func testAppointmentCreatesMissingRecordsAndAdditionalLocationWithoutLosingDraft() {
        let app = launch()
        defer { app.terminate() }
        openAppointment(in: app)
        reveal(app.buttons["appointment-add-service"], in: app)
        app.buttons["appointment-add-service"].tap()
        type("Trim\n", into: app.textFields["service-name-field"])
        type("45", into: app.textFields["service-price-field"])
        app.navigationBars["New Service"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
        addLocation("Alpha Barn", in: app)
        app.buttons["appointment-more-details"].tap()
        type("Keep this draft", into: app.textViews["Appointment Notes"])
        dismissKeyboard(in: app)
        guard openLocation(in: app) else { return }
        type("Canceled Barn", into: app.textFields["barn-name-field"])
        app.navigationBars["New Service Location"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["appointment-barn-picker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["appointment-barn-picker"].value.debugDescription.contains("Alpha Barn"))
        addLocation("Beta Barn", in: app)
        guard addHorse(in: app) else { return }
        let service = app.buttons["appointment-service-Setup Horse"]
        reveal(service, in: app)
        let choice = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Trim")).firstMatch
        for _ in 0..<2 {
            service.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
            if choice.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(choice.exists)
        choice.tap()
        XCTAssertTrue(String(describing: service.value).contains("Trim"))
        app.navigationBars["New Appointment"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["appointment-row-Beta Barn"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Schedule"].tap()
        let appointment = app.buttons["appointment-row-Beta Barn"]
        XCTAssertTrue(appointment.waitForExistence(timeout: 5))
        appointment.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        app.buttons["appointment-actions-menu"].tap()
        app.buttons["appointment-edit-action"].tap()
        let savedNotes = app.textViews["Appointment Notes"]
        reveal(savedNotes, in: app)
        XCTAssertEqual(savedNotes.value as? String, "Keep this draft")
        let savedService = app.buttons["appointment-service-Setup Horse"]
        reveal(savedService, in: app)
        XCTAssertTrue(String(describing: savedService.value).contains("Trim"))
        app.navigationBars["Edit Appointment"].buttons["Cancel"].tap()
    }

    @MainActor
    func testHorseLocationChangesRequireConfirmationInBothEntryPoints() {
        let app = launch()
        defer { app.terminate() }
        openAppointment(in: app)
        addLocation("Alpha Barn", in: app)
        addLocation("Beta Barn", in: app)
        guard addHorse(in: app) else { return }
        app.navigationBars["New Appointment"].buttons["Cancel"].tap()
        app.tabBars.buttons["Clients"].tap()
        app.buttons["client-row-Setup Client"].tap()
        app.buttons["horse-row-Setup Horse"].tap()
        app.buttons["Edit"].tap()
        app.buttons["horse-barn-picker"].tap()
        app.buttons["Alpha Barn"].tap()
        app.navigationBars["Edit Horse"].buttons["Save"].tap()
        let confirmation = app.alerts["Move to Another Location?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmation.staticTexts["Move Setup Horse from Beta Barn to Alpha Barn? Completed visit history will keep its original location."].exists)
        confirmation.buttons["Cancel"].tap()
        app.navigationBars["Edit Horse"].buttons["Cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["horse-detail-service-location"].label.contains("Beta Barn"))
        app.buttons["Edit"].tap()
        app.buttons["horse-barn-picker"].tap()
        app.buttons["Alpha Barn"].tap()
        app.navigationBars["Edit Horse"].buttons["Save"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Move Horse"].tap()
        XCTAssertTrue(app.navigationBars["Setup Horse"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Clients"].tap()
        app.buttons["client-row-Setup Client"].tap()
        app.buttons["horse-row-Setup Horse"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["horse-detail-service-location"].label.contains("Alpha Barn"))
        app.navigationBars.buttons["Client"].tap()
        app.navigationBars.buttons["Clients"].tap()
        app.openBusinessRoot()
        app.buttons["Service Locations"].tap()
        app.buttons["barn-row-Beta Barn"].tap()
        app.buttons["Actions"].tap()
        app.buttons["Add Existing Horse"].tap()
        app.descendants(matching: .any)["horse-row-Setup Horse"].firstMatch.tap()
        app.navigationBars["Add Existing Horse"].buttons["Move"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Add Existing Horse"].exists)
        app.navigationBars["Add Existing Horse"].buttons["Move"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Move Horse"].tap()
        XCTAssertTrue(app.buttons["horse-row-Setup Horse"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func verifyInitialServices(largestText: Bool, readOnly: Bool = false) {
        let app = launch(initialSetup: true, largestText: largestText, readOnly: readOnly)
        defer { app.terminate() }
        let start = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: start)
        waitForExpectations(timeout: 10)
        start.tap()
        type("Field Farrier", into: app.textFields["business-profile-name-field"])
        let add = app.buttons["business-setup-add-service"]
        reveal(add, in: app)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44)
        add.tap()
        type("Trim\n", into: app.textFields["service-name-field"])
        type("45", into: app.textFields["service-price-field"])
        dismissKeyboard(in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = largestText ? "Setup services largest text" : "Setup services"
        screenshot.lifetime = .keepAlways
        self.add(screenshot)
        app.buttons["business-profile-save-action"].tap()
        if readOnly {
            XCTAssertTrue(app.navigationBars["FarrierFlow Pro"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.navigationBars["Today"].exists)
            return
        }
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.tabBars.buttons["Clients"].tap()
        app.openBusinessRoot()
        app.buttons["Business Profile"].tap()
        let services = app.buttons["business-profile-services"]
        reveal(services, in: app)
        services.tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["service-row-Trim"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func launch(initialSetup: Bool = false, largestText: Bool = false, readOnly: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "AppointmentSetup-\(UUID())"
        if readOnly { app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only" }
        if initialSetup { app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup" }
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launch()
        return app
    }

    @MainActor
    private func openAppointment(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Schedule"].tap()
        app.buttons["Schedule Appointment"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func addLocation(_ name: String, in app: XCUIApplication) {
        guard openLocation(in: app) else { return }
        type(name, into: app.textFields["barn-name-field"])
        app.navigationBars["New Service Location"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openLocation(in app: XCUIApplication) -> Bool {
        let button = app.buttons["appointment-add-service-location"]
        for _ in 0..<2 {
            reveal(button, in: app)
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if app.textFields["barn-name-field"].waitForExistence(timeout: 3) { return true }
        }
        XCTFail("Add Service Location did not open its editor")
        return false
    }

    @MainActor
    private func addHorse(in app: XCUIApplication) -> Bool {
        let add = app.buttons["appointment-add-horse"]
        reveal(add, in: app)
        add.tap()
        guard type("Setup Horse", into: app.textFields["horse-name-field"]) else { return false }
        app.buttons["horse-client-picker"].tap()
        app.buttons["Create New Client"].tap()
        type("Setup Client", into: app.textFields["client-name-field"])
        app.navigationBars["New Client"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        app.navigationBars["New Horse"].buttons["Save"].tap()
        return app.navigationBars["New Appointment"].waitForExistence(timeout: 5)
    }

    @MainActor
    @discardableResult
    private func type(_ value: String, into field: XCUIElement) -> Bool {
        guard field.waitForExistence(timeout: 5) else {
            XCTFail("Expected input field \(field)")
            return false
        }
        let initialFocus = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field
        )
        if XCTWaiter.wait(for: [initialFocus], timeout: 2) == .completed {
            field.typeText(value)
            return true
        }
        reveal(field, in: XCUIApplication())
        for attempt in 0..<3 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: attempt == 0 ? 0.5 : 0.85)).tap()
            let focus = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field
            )
            if XCTWaiter.wait(for: [focus], timeout: 2) == .completed {
                field.typeText(value)
                return true
            }
        }
        XCTFail("Input field did not receive keyboard focus")
        return false
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            let top = app.navigationBars.allElementsBoundByIndex
                .filter(\.isHittable).map { $0.frame.maxY }.max() ?? app.frame.minY + 100
            var bottom = app.frame.maxY - 20
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists { bottom = min(bottom, keyboard.frame.minY) }
            let continueButton = app.buttons["business-profile-save-action"]
            if continueButton.exists && continueButton.frame.minY > app.frame.midY {
                bottom = min(bottom, continueButton.frame.minY)
            }
            let target = element.exists ? element.frame : .zero
            if element.exists, element.isHittable,
               target.midY > top + 8, target.midY < bottom - 8 { return }
            let surface = app.collectionViews.allElementsBoundByIndex.last(where: \.isHittable)
                ?? app.scrollViews.allElementsBoundByIndex.last(where: \.isHittable) ?? app
            if element.exists && target.midY <= top + 8 { surface.swipeDown() }
            else { surface.swipeUp() }
        }
        XCTFail("Expected element to be visible outside the keyboard and navigation bar: \(element)")
    }
}
