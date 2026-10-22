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
        continueAfterFailure = false
        let app = launch()
        defer { app.terminate() }
        openAppointment(in: app)
        XCTAssertFalse(app.buttons["appointment-add-service"].exists)
        XCTAssertFalse(app.textFields["appointment-duration"].exists)
        addLocation("Alpha Barn", in: app)
        app.buttons["appointment-additional-details"].tap()
        type("Keep this draft", into: app.textViews["Appointment Notes"])
        dismissKeyboard(in: app)
        guard openLocation(in: app) else { return }
        type("Canceled Barn", into: app.textFields["barn-name-field"])
        app.navigationBars["New Service Location"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["appointment-barn-picker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["appointment-barn-picker"].value.debugDescription.contains("Alpha Barn"))
        addLocation("Beta Barn", in: app)
        guard addHorse(in: app) else { return }
        let newHorse = app.buttons["appointment-create-horse"]
        reveal(newHorse, in: app)
        XCTAssertEqual(newHorse.label, "New Horse")
        newHorse.tap()
        app.navigationBars["New Horse"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["appointment-horse-Setup Horse"].value as? String, "Selected")
        let service = app.buttons["appointment-service-Setup Horse"]
        reveal(service, in: app)
        service.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["appointment-create-service"].tap()
        type("Trim\n", into: app.textFields["service-name-field"])
        type("45", into: app.textFields["service-price-field"])
        app.navigationBars["New Service"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
        reveal(service, in: app)
        XCTAssertTrue(String(describing: service.value).contains("Trim"))
        service.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["appointment-create-service"].tap()
        app.navigationBars["New Service"].buttons["Cancel"].tap()
        XCTAssertTrue(service.waitForExistence(timeout: 5))
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
    func testAppointmentHierarchyAndIndependentPlansPersist() {
        verifyAppointmentHierarchy(largestText: false)
    }

    @MainActor
    func testAppointmentHierarchySupportsLargestTextAndDurationValidation() {
        verifyAppointmentHierarchy(largestText: true)
    }

    @MainActor
    private func verifyAppointmentHierarchy(largestText: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "AppointmentHierarchy-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "next-appointment"
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launch()
        defer { app.terminate() }
        openAppointment(in: app)
        let save = app.navigationBars["New Appointment"].buttons["Save"]
        XCTAssertFalse(save.isEnabled)
        app.buttons["appointment-barn-picker"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let location = app.buttons["Next Appointment Service Location"]
        XCTAssertTrue(location.waitForExistence(timeout: 3))
        location.tap()
        if largestText { capture("Appointment location AX dark", in: app) }
        for name in ["Atlas", "Beacon"] {
            let horse = app.buttons["appointment-horse-\(name)"]
            reveal(horse, in: app)
            XCTAssertTrue(horse.label.contains("Next Appointment Client"))
            XCTAssertFalse(horse.label.contains("Service Location"))
            horse.tap()
            XCTAssertEqual(horse.value as? String, "Selected")
        }
        XCTAssertTrue(save.isEnabled)
        let details = app.buttons["appointment-additional-details"]
        reveal(details, in: app)
        XCTAssertFalse(app.textFields["appointment-duration"].exists)
        XCTAssertFalse(app.buttons["appointment-horse-options"].exists)
        let atlas = app.buttons["appointment-service-Atlas"]
        reveal(atlas, in: app, towardTop: true)
        XCTAssertEqual(atlas.value as? String, "Choose Service")
        XCTAssertFalse(app.textFields["appointment-duration"].exists)
        capture("Appointment visible plans \(largestText ? "AX dark" : "light")", in: app)
        if !largestText {
            atlas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons["appointment-create-service"].tap()
            type("Appointment Trim\n", into: app.textFields["service-name-field"])
            type("45", into: app.textFields["service-price-field"])
            app.navigationBars["New Service"].buttons["Save"].tap()
            XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
            reveal(atlas, in: app)
            XCTAssertTrue(String(describing: atlas.value).contains("Appointment Trim"))
            let beacon = app.buttons["appointment-service-Beacon"]
            reveal(beacon, in: app)
            XCTAssertFalse(String(describing: beacon.value).contains("Appointment Trim"))
        }
        // Deselecting removes only this horse's appointment plan; the other stays visible.
        let beaconHorse = app.buttons["appointment-horse-Beacon"]
        reveal(beaconHorse, in: app, towardTop: true)
        beaconHorse.tap()
        reveal(atlas, in: app)
        XCTAssertFalse(app.buttons["appointment-service-Beacon"].exists)
        if !largestText {
            XCTAssertTrue(String(describing: atlas.value).contains("Appointment Trim"))
        }
        reveal(beaconHorse, in: app, towardTop: true)
        beaconHorse.tap()
        let beacon = app.buttons["appointment-service-Beacon"]
        reveal(beacon, in: app)
        XCTAssertEqual(beacon.value as? String, "Choose Service")
        reveal(details, in: app)
        XCTAssertEqual(details.label, "Additional Details")
        details.tap()
        let duration = app.textFields["appointment-duration"]
        reveal(duration, in: app)
        type("0", into: duration, atTrailingEdge: true)
        dismissKeyboard(in: app)
        XCTAssertFalse(save.isEnabled)
        capture("Appointment details \(largestText ? "AX dark" : "light")", in: app)
        reveal(details, in: app, towardTop: true)
        details.tap()
        XCTAssertFalse(app.textFields["appointment-duration"].exists)
        XCTAssertFalse(save.isEnabled)
        let guidance = app.staticTexts["Enter a duration greater than zero, or leave it blank."]
        reveal(guidance, in: app)
        XCTAssertTrue(guidance.exists)
        reveal(details, in: app, towardTop: true)
        details.tap()
        reveal(duration, in: app)
        type(XCUIKeyboardKey.delete.rawValue, into: duration, atTrailingEdge: true)
        XCTAssertNotEqual(duration.value as? String, "0")
        dismissKeyboard(in: app)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Schedule"].tap()
        let row = app.buttons["appointment-row-Next Appointment Service Location"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["appointment-actions-menu"].tap()
        app.buttons["appointment-edit-action"].tap()
        let savedAtlas = app.buttons["appointment-service-Atlas"]
        reveal(savedAtlas, in: app)
        if !largestText {
            XCTAssertTrue(String(describing: savedAtlas.value).contains("Appointment Trim"))
        }
        let savedBeacon = app.buttons["appointment-service-Beacon"]
        reveal(savedBeacon, in: app)
        XCTAssertFalse(String(describing: savedBeacon.value).contains("Appointment Trim"))
        app.navigationBars["Edit Appointment"].buttons["Cancel"].tap()
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
        for _ in 0..<2 {
            app.tabBars.buttons["Schedule"].tap()
            if app.navigationBars["Schedule"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.navigationBars["Schedule"].exists)
        let schedule = app.navigationBars["Schedule"].buttons["Schedule Appointment"]
        XCTAssertTrue(schedule.waitForExistence(timeout: 3))
        schedule.tap()
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
        let button = app.buttons["appointment-barn-picker"]
        reveal(button, in: app)
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let create = app.buttons["appointment-create-location"]
        guard create.waitForExistence(timeout: 3) else {
            XCTFail("Location menu did not offer creation")
            return false
        }
        create.tap()
        if app.textFields["barn-name-field"].waitForExistence(timeout: 3) { return true }
        XCTFail("Create New Location did not open its editor")
        return false
    }

    @MainActor
    private func addHorse(in app: XCUIApplication) -> Bool {
        let newHorse = app.buttons["appointment-create-horse"]
        reveal(newHorse, in: app)
        XCTAssertEqual(newHorse.label, "New Horse")
        newHorse.tap()
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
    private func type(_ value: String, into field: XCUIElement, atTrailingEdge: Bool = false) -> Bool {
        guard field.waitForExistence(timeout: 5) else {
            XCTFail("Expected input field \(field)")
            return false
        }
        let initialFocus = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field
        )
        if !atTrailingEdge, XCTWaiter.wait(for: [initialFocus], timeout: 2) == .completed {
            field.typeText(value)
            return true
        }
        reveal(field, in: XCUIApplication())
        for attempt in 0..<3 {
            field.coordinate(withNormalizedOffset: CGVector(dx: atTrailingEdge ? 0.85 : 0.5, dy: [0.5, 0.75, 0.85][attempt])).tap()
            let focus = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field
            )
            if XCTWaiter.wait(for: [focus], timeout: 2) == .completed {
                field.typeText(value)
                return true
            }
        }
        let failureCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        failureCapture.name = "Input focus failure"
        failureCapture.lifetime = .keepAlways
        add(failureCapture)
        XCTFail("Input field did not receive keyboard focus: \(field.debugDescription); keyboard visible: \(XCUIApplication().keyboards.firstMatch.exists)")
        return false
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<10 {
            let top = app.navigationBars.allElementsBoundByIndex
                .filter(\.isHittable).map { $0.frame.maxY }.max() ?? app.frame.minY + 100
            var bottom = app.frame.maxY
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
            if (element.exists && target.midY <= top + 8) || (!element.exists && towardTop) {
                surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.25))
                    .press(forDuration: 0.05, thenDragTo: surface.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.02, dy: 0.75)
                    ))
            } else {
                surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.75))
                    .press(forDuration: 0.05, thenDragTo: surface.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.02, dy: 0.25)
                    ))
            }
        }
        capture("Scroll target failure", in: app)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Scroll target hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTFail("Expected element to be visible outside the keyboard and navigation bar: \(element)")
    }
}
