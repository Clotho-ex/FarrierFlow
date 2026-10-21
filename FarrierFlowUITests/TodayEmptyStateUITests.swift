import XCTest

final class TodayEmptyStateUITests: XCTestCase {
    @MainActor
    func testReadyStateOpensSchedulingWithoutRequiringAnExistingService() {
        let app = launch(scenario: "today-ready")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["No appointments scheduled"].waitForExistence(timeout: 5))
        assertNoTodayToolbarAction(in: app)
        let schedule = app.buttons["Schedule Appointment"]
        XCTAssertTrue(schedule.isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: "Schedule Appointment").count, 1)
        capture(app, "Today ready standard light")
        schedule.tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["appointment-add-service"].exists)
        app.navigationBars["New Appointment"].buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["No appointments scheduled"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testFirstClientAndHorseLeadToSchedulingAndPersistAfterRelaunch() {
        let app = launch(scenario: "today-empty")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Add your first client"].waitForExistence(timeout: 5))
        assertNoTodayToolbarAction(in: app)
        capture(app, "Today first client light")
        app.buttons["today-add-first-client"].tap()
        XCTAssertTrue(app.navigationBars["New Client"].waitForExistence(timeout: 3))
        app.navigationBars["New Client"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["today-add-first-client"].waitForExistence(timeout: 3))
        app.buttons["today-add-first-client"].tap()
        let clientName = app.textFields["client-name-field"]
        XCTAssertTrue(clientName.waitForExistence(timeout: 3))
        clientName.tap()
        clientName.typeText("First Client")
        app.navigationBars["New Client"].buttons["Save"].tap()

        let addHorse = app.buttons["today-add-first-horse"]
        XCTAssertTrue(addHorse.waitForExistence(timeout: 5))
        capture(app, "Today first horse light")
        addHorse.tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["horse-client-picker"].label.contains("First Client"))
        let horseName = app.textFields["horse-name-field"]
        horseName.tap()
        horseName.typeText("Milo")
        if app.buttons["horse-keyboard-done"].exists { app.buttons["horse-keyboard-done"].tap() }
        app.buttons["horse-barn-picker"].tap()
        let createLocation = app.buttons["Create New Service Location"]
        XCTAssertTrue(createLocation.waitForExistence(timeout: 3))
        createLocation.tap()
        let locationName = app.textFields["barn-name-field"]
        XCTAssertTrue(locationName.waitForExistence(timeout: 3))
        locationName.tap()
        locationName.typeText("North Field")
        app.navigationBars["New Service Location"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        app.navigationBars["New Horse"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["No appointments scheduled"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["No appointments scheduled"].waitForExistence(timeout: 5))
        assertNoTodayToolbarAction(in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "Schedule Appointment").count, 1)
        capture(app, "Today ready to schedule light")
        app.buttons["Schedule Appointment"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["appointment-add-service"].exists)
        app.navigationBars["New Appointment"].buttons["Cancel"].tap()
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.staticTexts["No upcoming appointments"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Use + to schedule work."].exists)
        XCTAssertTrue(app.navigationBars["Schedule"].buttons["Schedule Appointment"].isHittable)
        capture(app, "Schedule empty light")
    }

    @MainActor
    func testClearDayShowsFutureWorkAndViewSchedulePreservesTabHistory() {
        let app = launch(scenario: "today-future")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["No stops today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Your day is clear. Your next appointment is")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["No appointments scheduled"].exists)
        assertNoTodayToolbarAction(in: app)
        capture(app, "Today clear with future work light")
        app.buttons["View Schedule"].tap()
        XCTAssertTrue(app.tabBars.buttons["Schedule"].isSelected)
        let appointment = app.buttons["appointment-row-North Field"]
        XCTAssertTrue(appointment.waitForExistence(timeout: 3))
        appointment.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Today"].tap()
        app.buttons["View Schedule"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCompletedDayRetainsItsStopAndAppointment() {
        let app = launch(scenario: "today-complete")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["All done for today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No appointments scheduled"].exists)
        assertNoTodayToolbarAction(in: app)
        capture(app, "Today completed day light")
        let stop = app.buttons["today-stop-row"]
        XCTAssertTrue(stop.exists)
        XCTAssertTrue((stop.value as? String)?.contains("Work Complete") == true)
        stop.tap()
        XCTAssertTrue(app.navigationBars["Stop Details"].waitForExistence(timeout: 3))
        app.buttons["today-stop-appointment"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testEmptyActionsRemainReachableAtLargestTextInDarkMode() {
        for scenario in ["today-empty", "today-ready"] {
            let app = launch(scenario: scenario, largestText: true)
            let action = app.buttons[scenario == "today-empty" ? "today-add-first-client" : "Schedule Appointment"]
            XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
            for _ in 0..<4 {
                if action.exists && action.isHittable && action.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
                app.swipeUp()
            }
            XCTAssertTrue(action.isHittable)
            XCTAssertLessThan(action.frame.maxY, app.tabBars.firstMatch.frame.minY)
            capture(app, "\(scenario) largest text dark")
            action.tap()
            let title = scenario == "today-empty" ? "New Client" : "New Appointment"
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
            app.navigationBars[title].buttons["Cancel"].tap()
            app.terminate()
        }
    }

    @MainActor
    func testReadOnlyEmptyStateDoesNotOfferUnavailableCreation() {
        let app = launch(scenario: "today-ready", readOnly: true)
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["No appointments scheduled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Schedule Appointment"].exists)
        XCTAssertFalse(app.buttons["today-add-first-client"].exists)
        XCTAssertFalse(app.buttons["today-add-first-horse"].exists)
        capture(app, "Today empty read only")
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.staticTexts["No upcoming appointments"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Schedule Appointment"].exists)
        XCTAssertFalse(app.staticTexts["Use + to schedule work."].exists)
    }

    @MainActor
    private func launch(scenario: String, largestText: Bool = false, readOnly: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "TodayEmpty-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = readOnly ? "read-only" : "full"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText { app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func assertNoTodayToolbarAction(in app: XCUIApplication) {
        XCTAssertFalse(app.navigationBars["Today"].buttons["Schedule Appointment"].exists)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
