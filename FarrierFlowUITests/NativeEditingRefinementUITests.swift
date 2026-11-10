import XCTest

final class NativeEditingRefinementUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testAppointmentNotesRevealEntireInputAboveSpacedKeyboardAccessory() {
        verifyKeyboard(largestText: false)
    }

    @MainActor
    func testAppointmentNotesAtLargestTextRevealEntireInput() {
        verifyKeyboard(largestText: true)
    }

    @MainActor
    func testAppointmentDeleteUsesConciseNativeConfirmation() {
        let app = launch(scenario: "visit-workflow", dark: true)
        defer { app.terminate() }
        app.buttons["today-run-sheet-scheduled"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 5))
        app.buttons["appointment-actions-menu"].tap()
        app.buttons["appointment-delete-action"].tap()
        let alert = app.alerts["Delete Appointment?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["You can’t undo this."].exists)
        XCTAssertFalse(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "clients")).firstMatch.exists)
        XCTAssertTrue(alert.buttons["Cancel"].isHittable)
        capture("Concise native deletion colors dark", in: app)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].exists)
    }

    @MainActor
    func testPlannedServiceUsesCompactStandardFormRow() {
        let app = launch(scenario: "visit-workflow", dark: true)
        defer { app.terminate() }
        app.buttons["today-run-sheet-scheduled"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 5))
        app.buttons["appointment-actions-menu"].tap()
        app.buttons["appointment-edit-action"].tap()
        XCTAssertTrue(app.navigationBars["Edit Appointment"].waitForExistence(timeout: 3))
        let service = app.buttons["appointment-service-Burger"]
        reveal(service, in: app)
        XCTAssertLessThanOrEqual(service.frame.height, 56)
        XCTAssertTrue(service.isHittable)
        capture("Compact planned service uses native Form spacing", in: app)
        service.tap()
        XCTAssertTrue(app.buttons["Brushing"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testServiceInputsShareNativeDoneAccessory() {
        let app = launch(scenario: "visit-workflow")
        defer { app.terminate() }
        app.openBusinessRoot()
        let services = app.buttons["Services"].firstMatch
        reveal(services, in: app)
        services.tap()
        let addService = app.buttons["service-add-action"]
        if !addService.waitForExistence(timeout: 2), app.navigationBars["Business"].exists {
            services.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1)
        }
        XCTAssertTrue(addService.waitForExistence(timeout: 3))
        addService.tap()
        let name = app.textFields["service-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Hoof Check\n")
        let price = app.textFields["service-price-field"]
        XCTAssertTrue(price.waitForExistence(timeout: 3))
        XCTAssertTrue(NSPredicate(format: "hasKeyboardFocus == true").evaluate(with: price))
        price.typeText("25")
        let done = app.buttons["service-keyboard-done"].firstMatch
        XCTAssertTrue(done.isHittable)
        capture("Service price native Done accessory", in: app)
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "Hoof Check")
        app.navigationBars["New Service"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCompletedTodayItemOpensAppointmentDirectly() {
        let app = launch(scenario: "today-complete")
        defer { app.terminate() }
        let row = app.buttons["today-stop-row"].firstMatch
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Stop Details"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["appointment-summary"].firstMatch.exists)
        XCTAssertFalse(app.buttons["visit-start-action"].exists)
        capture("Completed Today opens Appointment directly", in: app)
        app.navigationBars.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func verifyKeyboard(largestText: Bool) {
        let app = launch(scenario: "visit-workflow", dark: true, largestText: largestText)
        defer { app.terminate() }
        app.selectFarrierFlowTab("Schedule")
        app.navigationBars["Schedule"].buttons["Schedule Appointment"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
        let details = app.buttons["appointment-additional-details"]
        reveal(details, in: app)
        details.tap()
        let notes = app.textViews["Appointment Notes"]
        reveal(notes, in: app)
        notes.tap()
        let done = app.buttons["appointment-keyboard-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCTAssertTrue(keyboard.keys.firstMatch.waitForExistence(timeout: 3), "Validation requires the visible software keyboard")
        XCTAssertLessThan(keyboard.frame.minY, app.frame.maxY)
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            notes.frame.minY >= app.navigationBars.firstMatch.frame.maxY &&
            notes.frame.maxY <= done.frame.minY - 4 &&
            done.frame.maxY <= keyboard.frame.minY - 6
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed,
                       "Input: \(notes.frame), accessory: \(done.frame), keyboard: \(keyboard.frame)")
        capture("Full appointment notes above keyboard \(largestText ? "AX5" : "standard")", in: app)
        notes.typeText("Keep the entire input visible.")
        done.tap()
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        XCTAssertEqual(notes.value as? String, "Keep the entire input visible.")
        let duration = app.textFields["appointment-duration"]
        reveal(duration, in: app, towardTop: true)
        duration.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        let durationVisible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            duration.frame.minY >= app.navigationBars.firstMatch.frame.maxY && duration.frame.maxY <= done.frame.minY - 4
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [durationVisible], timeout: 5), .completed)
        capture("Duration input and native accessory \(largestText ? "AX5" : "standard")", in: app)
        done.tap()
    }

    @MainActor
    private func launch(scenario: String, dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "NativeEditing-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["FARRIERFLOW_UI_TEST_NOW"] = "2026-10-28T12:00:00Z"
        if dark { app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark" }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<10 {
            let tabBar = app.tabBars.firstMatch
            let bottom = tabBar.exists && tabBar.isHittable ? tabBar.frame.minY : app.frame.maxY - 24
            if element.exists && element.isHittable && element.frame.midY < bottom && element.frame.midY > app.navigationBars.firstMatch.frame.maxY { return }
            if towardTop { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
