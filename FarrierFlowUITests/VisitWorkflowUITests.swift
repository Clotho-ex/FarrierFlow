import XCTest

final class VisitWorkflowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testPlannedServiceAndSaveProgressOnlyEnableForChanges() {
        let app = launch()
        defer { app.terminate() }
        app.selectFarrierFlowTab("Schedule")
        let appointment = app.buttons["appointment-row-The Clarkson Farm"].firstMatch
        reveal(appointment, in: app)
        appointment.tap()
        let start = app.buttons["visit-start-action"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        let save = app.buttons["visit-save-progress"]
        XCTAssertFalse(save.isEnabled)
        let planned = app.buttons["visit-record-planned-Burger"]
        reveal(planned, in: app)
        XCTAssertTrue(planned.label.contains("Mark as Performed"), planned.label)
        XCTAssertFalse(app.staticTexts["visit-work-items-empty-Burger"].exists)
        capture("Planned service with disabled grey Save Progress", in: app)
        planned.tap()
        XCTAssertEqual(app.staticTexts["visit-progress-summary"].label, "1 service recorded")
        XCTAssertTrue(app.staticTexts["visit-pending-outcomes"].exists)
        XCTAssertTrue(save.isEnabled)
        assertTotal("visit-draft-total", contains: "$100.00", in: app)
        capture("Performed service enables Save Progress", in: app)
        save.tap()
        XCTAssertFalse(save.isEnabled)
        assertTotal("visit-saved-total", contains: "$100.00", in: app)
        XCTAssertEqual(app.staticTexts["visit-progress-summary"].label, "1 service recorded")
        capture("Saved progress returns to disabled grey", in: app)
        chooseOutcome("Serviced", in: app)
        XCTAssertTrue(app.buttons["visit-complete"].isEnabled)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertFalse(save.isEnabled)
        capture("Saved progress stays grey beside completion", in: app)
        app.buttons["visit-close"].tap()
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        resumeFromSchedule(in: app)
        XCTAssertFalse(save.isEnabled)
        assertTotal("visit-saved-total", contains: "$100.00", in: app)
        XCTAssertTrue(app.buttons["visit-complete"].isEnabled)
    }

    @MainActor
    func testProgressLivePriceResumeAndExplicitCompletion() {
        let app = launch()
        defer { app.terminate() }
        startFromStop(in: app)
        XCTAssertTrue(app.buttons["visit-record-planned-Burger"].exists)
        XCTAssertFalse(app.buttons["visit-work-item-Burger-Brushing"].exists)
        setNote("Return through the west gate.", in: app)
        XCTAssertTrue(app.buttons["visit-save-progress"].isEnabled)
        capture("Unresolved notes and keyboard above Save Progress", in: app)
        app.buttons["visit-save-progress"].tap()
        XCTAssertTrue(app.staticTexts["visit-unsaved-state"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["visit-close"].tap()
        app.terminate()
        app.launch()
        resumeFromSchedule(in: app)
        let notesToggle = app.buttons["visit-work-notes-toggle-Burger"]
        reveal(notesToggle, in: app)
        XCTAssertTrue(notesToggle.label.contains("west gate"), notesToggle.label)
        let record = app.buttons["visit-record-planned-Burger"]
        reveal(record, in: app)
        record.tap()
        assertTotal("visit-draft-total", contains: "$100.00", in: app)
        let work = app.buttons["visit-work-item-Burger-Brushing"]
        reveal(work, in: app)
        work.tap()
        XCTAssertTrue(app.navigationBars["Edit Visit Service"].waitForExistence(timeout: 3))
        replaceText("225", in: app.textFields["work-item-price-field"], app: app)
        app.buttons["work-item-keyboard-done"].tap()
        app.navigationBars["Edit Visit Service"].buttons["Save"].tap()
        assertTotal("visit-draft-total", contains: "$225.00", in: app)
        chooseOutcome("Serviced", in: app)
        XCTAssertTrue(app.buttons["visit-complete"].exists)
        XCTAssertTrue(app.buttons["visit-save-progress"].isEnabled)
        capture("Performed work live total and independent completion actions", in: app)
        app.buttons["visit-save-progress"].tap()
        assertTotal("visit-saved-total", contains: "$225.00", in: app)
        XCTAssertFalse(app.buttons["visit-save-progress"].isEnabled)
        app.buttons["visit-close"].tap()
        resumeFromSchedule(in: app)
        assertTotal("visit-saved-total", contains: "$225.00", in: app)
        app.buttons["visit-complete"].tap()
        XCTAssertTrue(app.navigationBars["Schedule Next Visit"].waitForExistence(timeout: 5))
        capture("Explicit next appointment actions", in: app)
        app.buttons["next-appointment-not-now"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready to Invoice"].exists)
        app.selectFarrierFlowTab("Schedule")
        if app.navigationBars["Appointment"].exists {
            app.navigationBars["Appointment"].buttons["Schedule"].tap()
        }
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "appointment-row-The Clarkson Farm").count, 0)
    }

    @MainActor
    func testNotServicedPreservesWorkAndReasonUntilExplicitRemovalAtLargestText() {
        let app = launch(largestText: true)
        defer { app.terminate() }
        startFromStop(in: app)
        let record = app.buttons["visit-record-planned-Burger"]
        reveal(record, in: app)
        record.tap()
        setNote("Horse could not be handled safely.", in: app)
        app.buttons["visit-dismiss-keyboard"].tap()
        chooseOutcome("Not Serviced", in: app)
        XCTAssertFalse(app.alerts["Clear Recorded Work?"].exists)
        let conflict = app.staticTexts["visit-outcome-conflict-Burger"]
        reveal(conflict, in: app)
        XCTAssertTrue(conflict.exists)
        XCTAssertFalse(app.buttons["visit-complete"].exists)
        app.buttons["visit-save-progress"].tap()
        app.buttons["visit-close"].tap()
        app.terminate()
        app.launch()
        resumeFromSchedule(in: app)
        let work = app.buttons["visit-work-item-Burger-Brushing"]
        reveal(work, in: app)
        XCTAssertTrue(work.exists)
        work.tap()
        reveal(app.buttons["visit-remove-service"], in: app)
        app.buttons["visit-remove-service"].tap()
        XCTAssertTrue(app.alerts["Remove Service?"].waitForExistence(timeout: 3))
        app.alerts["Remove Service?"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit Visit Service"].exists)
        app.buttons["visit-remove-service"].tap()
        app.alerts["Remove Service?"].buttons["Remove Service"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        XCTAssertFalse(work.exists)
        let note = app.buttons["visit-work-notes-toggle-Burger"]
        reveal(note, in: app)
        XCTAssertTrue(note.label.contains("handled safely"), note.label)
        capture("Not Serviced retains reason after explicit service removal AX dark", in: app)
        XCTAssertTrue(app.buttons["visit-complete"].isEnabled)
        app.buttons["visit-complete"].tap()
        XCTAssertTrue(app.navigationBars["Schedule Next Visit"].waitForExistence(timeout: 5))
        app.buttons["next-appointment-not-now"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Ready to Invoice"].exists)
        app.openBusinessRoot()
        let history = app.buttons["Recorded Work"]
        reveal(history, in: app)
        history.tap()
        let visit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "business-completed-visit-")).firstMatch
        reveal(visit, in: app)
        visit.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        let reason = app.descendants(matching: .any)["visit-result-notes-Burger"].firstMatch
        reveal(reason, in: app)
        XCTAssertTrue(reason.label.contains("Reason"), reason.label)
        XCTAssertTrue(reason.label.contains("handled safely"), reason.label)
        XCTAssertFalse(app.descendants(matching: .any)["visit-detail-total"].exists)
        capture("Saved attendance reason in Recorded Work AX dark", in: app)
    }

    @MainActor
    func testNextAppointmentRequiresTheExplicitScheduleAction() {
        let app = launch()
        defer { app.terminate() }
        startFromStop(in: app)
        let record = app.buttons["visit-record-planned-Burger"]
        reveal(record, in: app)
        record.tap()
        chooseOutcome("Serviced", in: app)
        app.buttons["visit-complete"].tap()
        let assistantPresented = app.navigationBars["Schedule Next Visit"].waitForExistence(timeout: 5)
        if !assistantPresented { capture("Next appointment presentation failure", in: app) }
        XCTAssertTrue(assistantPresented, app.debugDescription)
        let schedule = app.buttons["next-appointment-confirm"]
        XCTAssertEqual(schedule.label, "Schedule Next Appointment")
        XCTAssertTrue(schedule.isHittable)
        XCTAssertGreaterThan(schedule.frame.width, app.frame.width * 0.8)
        XCTAssertFalse(app.staticTexts["Suggestion unavailable"].exists)
        let notNow = app.buttons["next-appointment-not-now"]
        XCTAssertLessThanOrEqual(notNow.frame.maxY, app.frame.maxY - 8)
        capture("Single horse next visit explicit full-width action", in: app)
        schedule.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        app.selectFarrierFlowTab("Schedule")
        XCTAssertEqual(app.buttons.matching(identifier: "appointment-row-The Clarkson Farm").count, 1)
        app.terminate()
        app.launch()
        app.selectFarrierFlowTab("Schedule")
        XCTAssertEqual(app.buttons.matching(identifier: "appointment-row-The Clarkson Farm").count, 1)
    }

    @MainActor
    private func launch(largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "VisitWorkflow-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "visit-workflow"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_NOW"] = "2026-10-27T12:00:00Z"
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func startFromStop(in app: XCUIApplication) {
        let stop = app.buttons["today-run-sheet-scheduled"]
        XCTAssertTrue(stop.waitForExistence(timeout: 3))
        stop.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.navigationBars["Stop Details"].exists)
        capture("Today opens Appointment directly", in: app)
        let start = app.buttons["visit-start-action"]
        start.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func resumeFromSchedule(in app: XCUIApplication) {
        app.selectFarrierFlowTab("Schedule")
        if !app.navigationBars["Appointment"].exists {
            let appointment = app.buttons["appointment-row-The Clarkson Farm"].firstMatch
            reveal(appointment, in: app)
            appointment.tap()
        }
        let resume = app.buttons["visit-resume-action"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        resume.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func setNote(_ text: String, in app: XCUIApplication) {
        let toggle = app.buttons["visit-work-notes-toggle-Burger"]
        reveal(toggle, in: app)
        toggle.tap()
        replaceText(text, in: app.descendants(matching: .any)["visit-work-notes-Burger"].firstMatch, app: app)
    }

    @MainActor
    private func chooseOutcome(_ title: String, in app: XCUIApplication) {
        let picker = app.descendants(matching: .any)["visit-outcome-Burger"].firstMatch
        reveal(picker, in: app)
        if app.buttons[title].exists { app.buttons[title].tap() }
        else {
            picker.tap()
            app.buttons[title].tap()
        }
    }

    @MainActor
    private func assertTotal(_ id: String, contains value: String, in app: XCUIApplication) {
        let total = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        XCTAssertTrue(total.label.contains(value), total.label)
    }

    @MainActor
    private func replaceText(_ value: String, in field: XCUIElement, app: XCUIApplication) {
        reveal(field, in: app)
        field.tap()
        let previous = field.value as? String ?? ""
        if !previous.isEmpty, previous != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(value)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<24 {
            let bar = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).max { $0.frame.maxY < $1.frame.maxY }
            let top = bar?.frame.maxY ?? 100
            let isVisit = bar?.identifier == "Visit"
            let footer = app.otherElements["visit-footer"].firstMatch
            let footerTop = isVisit && footer.exists ? footer.frame.minY : app.frame.maxY
            let bottom = min(footerTop, app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY
                : app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY)
            if element.exists, element.isHittable, element.frame.midY > top + 4, element.frame.midY < bottom - 4 { return }
            let surface = app.collectionViews.allElementsBoundByIndex.last(where: \.isHittable) ?? app
            let down = element.exists && element.frame.midY < top
            let visibleTop = max(top + 4, surface.frame.minY)
            let visibleBottom = min(bottom - 4, surface.frame.maxY)
            let height = max(0, visibleBottom - visibleTop)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = surface.frame.minX + surface.frame.width * 0.02 - app.frame.minX
            origin.withOffset(CGVector(dx: x, dy: visibleTop + height * (down ? 0.25 : 0.75) - app.frame.minY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: visibleTop + height * (down ? 0.75 : 0.25) - app.frame.minY)))
        }
        capture("Unreachable workflow target", in: app)
        XCTFail("Unreachable target: \(element); \(app.debugDescription)")
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
