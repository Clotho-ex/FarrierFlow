import XCTest

final class ScheduleRowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
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
        let completed = row("Oak Barn", in: app)
        reveal(completed, in: app)
        XCTAssertTrue(completed.label.contains("Completed"), completed.label)
        capture("Schedule active and completed work", in: app)
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
            let top = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable)
                .map { $0.frame.maxY }.max() ?? 100
            let bottom = app.tabBars.firstMatch.frame.minY
            if element.exists, element.isHittable,
               element.frame.midY > top + 8, element.frame.midY < bottom - 8 { return }
            let surface = app.collectionViews.firstMatch
            surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.8))
                .press(forDuration: 0.05, thenDragTo: surface.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.02, dy: 0.25)
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
