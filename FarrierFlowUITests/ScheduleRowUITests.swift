import XCTest

final class ScheduleRowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testCreatingFromCompletedShowsScheduledAndClearsOnlyItsFilter() {
        let app = launch()
        defer { app.terminate() }
        let tabs = app.segmentedControls["schedule-status-tabs"]
        XCTAssertGreaterThanOrEqual(tabs.frame.minY, app.navigationBars["Schedule"].frame.maxY - 1,
                                    "Status controls must sit below the native navigation title")
        app.buttons["schedule-service-filter"].tap()
        let filterOption = app.buttons["Full Set"].firstMatch
        filterOption.tap()
        XCTAssertTrue(filterOption.waitForNonExistence(timeout: 3))
        tabs.buttons["Completed"].tap()
        XCTAssertTrue(row("Oak Barn", in: app).waitForExistence(timeout: 3))
        app.buttons["Schedule Appointment"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
        app.navigationBars["New Appointment"].buttons["Cancel"].tap()
        XCTAssertTrue(row("Oak Barn", in: app).waitForExistence(timeout: 3), "Cancel keeps completed appointments visible")
        capture("Cancel retains Completed", in: app)
        app.buttons["Schedule Appointment"].tap()
        let barnPicker = app.descendants(matching: .any)["appointment-barn-picker"].firstMatch
        barnPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let barn = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "The Old Barn")).firstMatch
        XCTAssertTrue(barn.waitForExistence(timeout: 3), app.debugDescription)
        barn.tap()
        let horse = app.buttons["appointment-horse-Peanut"]
        XCTAssertTrue(horse.waitForExistence(timeout: 3))
        if !(horse.value as? String == "Selected") { horse.tap() }
        let save = app.navigationBars["New Appointment"].buttons["Save"]
        XCTAssertTrue(save.isEnabled, app.debugDescription)
        save.tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("The Old Barn", in: app).firstMatch.waitForExistence(timeout: 5),
                      "A newly saved appointment must not be hidden by the old service filter")
        XCTAssertFalse(row("Oak Barn", in: app).exists)
        capture("Created appointment returns to Scheduled", in: app)
    }

    @MainActor
    func testServiceAppointmentsRefreshAfterCompletingLinkedVisit() {
        let app = launch()
        defer { app.terminate() }
        app.openBusinessRoot()
        let services = app.buttons["Services"]
        reveal(services, in: app)
        services.tap()
        let trim = app.buttons["service-row-Trim"]
        XCTAssertTrue(trim.waitForExistence(timeout: 3))
        trim.tap()
        let linked = app.buttons["linked-appointment-East Barn"]
        reveal(linked, in: app)
        linked.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 5))
        app.buttons["appointment-actions-menu"].tap()
        app.buttons["appointment-delete-action"].tap()
        let protection = app.alerts["Visit History Must Be Kept"]
        XCTAssertTrue(protection.waitForExistence(timeout: 5))
        protection.buttons["OK"].tap()
        app.buttons["visit-resume-action"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        let record = app.buttons["visit-record-planned-Horse 4-1"]
        reveal(record, in: app)
        record.tap()
        let outcome = app.buttons["visit-outcome-Horse 4-1"]
        if !outcome.exists { app.buttons["visit-horse-toggle-Horse 4-1"].tap() }
        reveal(outcome, in: app)
        outcome.tap()
        app.buttons["Serviced"].firstMatch.tap()
        let complete = app.buttons["visit-complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 3))
        XCTAssertTrue(complete.isEnabled)
        complete.tap()
        XCTAssertTrue(app.navigationBars["Schedule Next Visit"].waitForExistence(timeout: 5))
        app.buttons["next-appointment-not-now"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.selectFarrierFlowTab("Business")
        app.navigationBars.buttons["Trim"].tap()
        XCTAssertTrue(app.navigationBars["Trim"].waitForExistence(timeout: 5))
        XCTAssertFalse(linked.exists, "Completed work must leave the service's Appointments tab")
        let tabs = app.segmentedControls["service-history-tabs"]
        reveal(tabs, in: app)
        tabs.buttons["Recorded Work"].tap()
        let recorded = app.buttons["linked-visit-Horse 4-1"]
        reveal(recorded, in: app)
        XCTAssertTrue(recorded.label.contains("Completed"), recorded.label)
        capture("Service completed work appears only in Recorded Work", in: app)
    }

    @MainActor
    func testCompletedAppointmentCannotDeleteRecordedVisit() {
        let app = launch()
        defer { app.terminate() }
        app.segmentedControls["schedule-status-tabs"].buttons["Completed"].tap()
        let completed = row("Oak Barn", in: app)
        reveal(completed, in: app)
        openAppointment(completed, in: app)
        app.buttons["Appointment Actions"].tap()
        app.buttons["appointment-delete-action"].tap()
        let protection = app.alerts["Visit History Must Be Kept"]
        XCTAssertTrue(protection.waitForExistence(timeout: 3))
        capture("Appointment deletion preserves visit history", in: app)
        protection.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["View Completed Visit"].exists)
        app.buttons["View Completed Visit"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPopulatedScheduleShowsRealPlansStatesAndOwnersAfterRelaunch() {
        let app = launch()
        defer { app.terminate() }
        let oldBarn = row("The Old Barn", in: app)
        reveal(oldBarn, in: app)
        XCTAssertTrue(oldBarn.label.contains("Peanut · John Doe"), oldBarn.label)
        XCTAssertTrue(oldBarn.label.contains("Scheduled"), oldBarn.label)
        XCTAssertTrue(oldBarn.label.contains("Trim"), oldBarn.label)
        capture("Schedule populated list light", in: app)
        openAppointment(oldBarn, in: app)
        let planned = app.descendants(matching: .any)["appointment-planned-service-Peanut"].firstMatch
        XCTAssertTrue(planned.waitForExistence(timeout: 5))
        XCTAssertTrue(planned.label.contains("Trim"), planned.label)
        app.navigationBars["Appointment"].buttons.firstMatch.tap()
        verifyRemainingRows(in: app, allRows: true)
        app.terminate()
        app.launch()
        app.selectFarrierFlowTab("Schedule")
        let saved = row("The Old Barn", in: app)
        reveal(saved, in: app)
        XCTAssertTrue(saved.label.contains("Peanut · John Doe"), saved.label)
        XCTAssertTrue(saved.label.contains("Trim"), saved.label)
        capture("Schedule persisted populated list", in: app)
    }

    @MainActor
    func testScheduleAtLargestTextInDarkModeKeepsNativeNavigationAndBoundedSummaries() {
        let app = launch(largestText: true)
        defer { app.terminate() }
        let oldBarn = row("The Old Barn", in: app)
        reveal(oldBarn, in: app)
        XCTAssertTrue(oldBarn.label.contains("Peanut · John Doe"), oldBarn.label)
        XCTAssertTrue(oldBarn.label.contains("Scheduled"), oldBarn.label)
        XCTAssertTrue(oldBarn.label.contains("Trim"), oldBarn.label)
        capture("Schedule single plan AX dark", in: app)
        verifyRemainingRows(in: app, allRows: false)
        let last = row("Hill Barn", in: app)
        reveal(last, in: app)
        XCTAssertTrue(last.label.contains("A Horse With a Particularly Long Registered Name"), last.label)
        capture("Schedule long horse name AX dark", in: app)
        openAppointment(last, in: app)
    }

    @MainActor
    func testCompletedAppointmentKeepsOriginalPlanBehindDisclosure() {
        verifyCompletedOriginalPlan(largestText: false)
    }

    @MainActor
    func testCompletedOriginalPlanAtLargestTextInDarkMode() {
        verifyCompletedOriginalPlan(largestText: true)
    }

    @MainActor
    func testServiceFiltersRemainIndependentAcrossStatusTabs() {
        let app = launch()
        defer { app.terminate() }
        let tabs = app.segmentedControls["schedule-status-tabs"]
        app.buttons["schedule-service-filter"].tap()
        app.buttons["Full Set"].firstMatch.tap()
        XCTAssertFalse(row("The Old Barn", in: app).exists)
        let planned = row("River Barn", in: app)
        reveal(planned, in: app)
        XCTAssertTrue(planned.exists)
        capture("Scheduled service filter", in: app)
        tabs.buttons["Completed"].tap()
        let completed = row("Oak Barn", in: app)
        reveal(completed, in: app)
        XCTAssertTrue(completed.label.contains("Completed"))
        app.buttons["schedule-service-filter"].tap()
        app.buttons["Trim"].firstMatch.tap()
        XCTAssertTrue(completed.waitForExistence(timeout: 3))
        capture("Completed actual-service filter", in: app)
        tabs.buttons["Scheduled"].tap()
        XCTAssertFalse(row("The Old Barn", in: app).exists)
        reveal(planned, in: app)
        XCTAssertTrue(planned.exists)
        app.buttons["schedule-service-filter"].tap()
        app.buttons["All Services"].firstMatch.tap()
        let original = row("The Old Barn", in: app)
        reveal(original, in: app)
        XCTAssertTrue(original.exists)
    }

    @MainActor
    func testCompletingVisitMovesItsScheduleRowWithoutRelaunch() {
        let app = launch()
        defer { app.terminate() }
        let active = row("East Barn", in: app)
        reveal(active, in: app)
        XCTAssertTrue(active.label.contains("In Progress"))
        openAppointment(active, in: app)
        app.buttons["visit-resume-action"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        let record = app.buttons["visit-record-planned-Horse 4-1"]
        reveal(record, in: app)
        record.tap()
        let outcome = app.descendants(matching: .any)["visit-outcome-Horse 4-1"].firstMatch
        if !outcome.exists { app.buttons["visit-horse-toggle-Horse 4-1"].tap() }
        reveal(outcome, in: app)
        outcome.tap()
        let serviced = app.buttons["Serviced"].firstMatch
        XCTAssertTrue(serviced.waitForExistence(timeout: 3))
        serviced.tap()
        let complete = app.buttons["visit-complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 3))
        XCTAssertTrue(complete.isHittable)
        XCTAssertTrue(complete.isEnabled)
        complete.tap()
        XCTAssertTrue(app.navigationBars["Schedule Next Visit"].waitForExistence(timeout: 5))
        app.buttons["next-appointment-not-now"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.selectFarrierFlowTab("Schedule")
        XCTAssertTrue(app.buttons["visit-view-action"].exists)
        app.navigationBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
        XCTAssertTrue(active.waitForNonExistence(timeout: 3))
        app.segmentedControls["schedule-status-tabs"].buttons["Completed"].tap()
        reveal(active, in: app)
        XCTAssertTrue(active.label.contains("Completed"), active.label)
        capture("Live completion moves Schedule row to Completed", in: app)
    }

    @MainActor
    private func verifyCompletedOriginalPlan(largestText: Bool) {
        let app = launch(largestText: largestText)
        defer { app.terminate() }
        app.segmentedControls["schedule-status-tabs"].buttons["Completed"].tap()
        let completed = row("Oak Barn", in: app)
        reveal(completed, in: app)
        XCTAssertTrue(completed.label.contains("Completed"))
        XCTAssertFalse(completed.label.contains("Planned Services"))
        XCTAssertFalse(completed.label.contains("Trim"))
        capture("Completed Schedule card without plan breakdown", in: app)
        openAppointment(completed, in: app)
        XCTAssertTrue(app.buttons["visit-view-action"].label.contains("View Completed Visit"))
        XCTAssertFalse(app.descendants(matching: .any)["appointment-planned-service-Horse 5-1"].exists)
        let original = app.buttons["appointment-original-plan"]
        reveal(original, in: app)
        XCTAssertFalse(app.descendants(matching: .any)["appointment-original-plan-Horse 5-1"].exists)
        original.tap()
        let plan = app.descendants(matching: .any)["appointment-original-plan-Horse 5-1"].firstMatch
        reveal(plan, in: app)
        XCTAssertTrue(plan.waitForExistence(timeout: 3))
        XCTAssertTrue(plan.label.contains("Trim"))
        capture("Completed Appointment original plan disclosure AX \(largestText)", in: app)
        if largestText { return }
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.selectFarrierFlowTab("Schedule")
        app.segmentedControls["schedule-status-tabs"].buttons["Completed"].tap()
        let saved = row("Oak Barn", in: app)
        reveal(saved, in: app)
        XCTAssertFalse(saved.label.contains("Planned Services"))
        openAppointment(saved, in: app)
        reveal(original, in: app)
        original.tap()
        XCTAssertTrue(plan.waitForExistence(timeout: 3))
        XCTAssertTrue(plan.label.contains("Trim"))
    }

    @MainActor
    private func openAppointment(_ row: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<3 {
            // Exercise the row's empty trailing area as well as its visible text.
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            if app.navigationBars["Appointment"].waitForExistence(timeout: 3) { return }
        }
        capture("Schedule navigation failure", in: app)
        XCTFail("Schedule row did not open its native detail: \(app.debugDescription)")
    }

    @MainActor
    private func verifyRemainingRows(in app: XCUIApplication, allRows: Bool) {
        let unplanned = row("North Field", in: app)
        reveal(unplanned, in: app)
        XCTAssertTrue(unplanned.label.contains("Thunder · John Doe"), unplanned.label)
        XCTAssertFalse(unplanned.label.contains("Planned Services"), unplanned.label)
        XCTAssertFalse(unplanned.label.contains("Full Set"), unplanned.label)
        let multiple = row("River Barn", in: app)
        reveal(multiple, in: app)
        XCTAssertTrue(multiple.label.contains("3 horses · 2 clients"), multiple.label)
        XCTAssertTrue(multiple.label.contains("2 of 3 horses"), multiple.label)
        XCTAssertTrue(multiple.label.contains("Full Set") && multiple.label.contains("Trim"), multiple.label)
        capture("Schedule partial multi horse plans", in: app)
        let active = row("East Barn", in: app)
        reveal(active, in: app)
        XCTAssertTrue(active.label.contains("In Progress"), active.label)
        app.segmentedControls["schedule-status-tabs"].buttons["Completed"].tap()
        let completed = row("Oak Barn", in: app)
        reveal(completed, in: app)
        XCTAssertTrue(completed.label.contains("Completed"), completed.label)
        XCTAssertFalse(completed.label.contains("Planned Services"), completed.label)
        capture("Schedule active and completed work", in: app)
        app.segmentedControls["schedule-status-tabs"].buttons["Scheduled"].tap()
        if allRows {
            for name in ["South Barn", "Meadow Barn", "The Long Meadow Equestrian Service Location", "Hill Barn", "West Barn"] {
                let appointment = row(name, in: app)
                reveal(appointment, in: app)
                XCTAssertTrue(appointment.label.contains("Scheduled"), appointment.label)
            }
            capture("Schedule ten appointments bottom", in: app)
        }
    }

    @MainActor
    private func launch(largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "ScheduleRows-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "schedule-rows"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_NOW"] = "2026-10-22T18:00:00Z"
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        app.selectFarrierFlowTab("Schedule")
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func row(_ barn: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["appointment-row-\(barn)"]
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<35 {
            let top = app.navigationBars.allElementsBoundByIndex
                .map { $0.frame.maxY }.max() ?? 100
            let bottom = app.tabBars.firstMatch.frame.minY
            if element.exists, element.isHittable,
               element.frame.midY > top + 8, element.frame.midY < bottom - 8 { return }
            let surface = app.collectionViews.firstMatch
            let above = element.exists && element.frame.midY <= top + 8
            surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.25 : 0.8))
                .press(forDuration: 0.05, thenDragTo: surface.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.8 : 0.25)
                ))
        }
        capture("Schedule row reveal failure", in: app)
        XCTFail("Expected Schedule row to be visible: \(element); \(app.debugDescription)")
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
