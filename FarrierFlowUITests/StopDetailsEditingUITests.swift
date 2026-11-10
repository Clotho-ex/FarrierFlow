import XCTest

final class StopDetailsEditingUITests: XCTestCase {
    @MainActor
    func testNativeDeleteConfirmationCancelPreservesAppointment() {
        let app = launch("CompactDelete-\(UUID().uuidString)")
        defer { app.terminate() }
        app.tabBars.buttons["Schedule"].tap()
        openSchedulePeanut(in: app)
        openDeletion(in: app)
        let alert = app.alerts["Delete Appointment?"]
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.isHittable)
        XCTAssertTrue(alert.exists)
        capture(app, "Delete confirmation fits standard text")
        cancel.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Schedule"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "appointment-row-The Old Barn").count, 2)
    }

    @MainActor
    func testDeleteConfirmationAccommodatesLargestTextAndDeletesAppointment() {
        let app = launch("AccessibleDelete-\(UUID().uuidString)", dynamicType: "accessibility5")
        defer { app.terminate() }
        for _ in 0..<4 {
            if app.buttons["today-stop-row"].exists { break }
            app.swipeUp()
        }
        openAppointment("Peanut", in: app)
        openDeletion(in: app)
        let alert = app.alerts["Delete Appointment?"]
        XCTAssertTrue(alert.exists)
        let cancel = app.buttons["Cancel"]
        reveal(cancel, in: app)
        XCTAssertTrue(cancel.isHittable)
        capture(app, "Delete confirmation accommodates largest text")
        let confirm = app.buttons["appointment-delete-confirmation"].firstMatch
        reveal(confirm, in: app)
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "today-stop-row").count, 1)
        XCTAssertTrue((app.buttons["today-stop-row"].value as? String)?.contains("Thunder") == true)
    }

    @MainActor
    private func openDeletion(in app: XCUIApplication) {
        app.buttons["appointment-actions-menu"].tap()
        app.buttons["appointment-delete-action"].tap()
        XCTAssertTrue(app.buttons["appointment-delete-confirmation"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSavingFromScheduleRefreshesTodayAndTheSharedDetail() {
        let app = launch("ScheduleToStopEditing-\(UUID().uuidString)")
        defer { app.terminate() }
        app.tabBars.buttons["Schedule"].tap()
        openSchedulePeanut(in: app)
        openEditor(in: app)
        let notes = app.textViews["Appointment Notes"]
        reveal(notes, in: app)
        notes.tap()
        notes.typeText("Saved from Schedule")
        app.buttons["appointment-keyboard-done"].tap()
        app.navigationBars["Edit Appointment"].buttons["Save"].tap()
        let savedNotes = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Saved from Schedule")).firstMatch
        XCTAssertTrue(savedNotes.waitForExistence(timeout: 3))
        app.tabBars.buttons["Today"].tap()
        openAppointment("Peanut", in: app)
        XCTAssertTrue(savedNotes.waitForExistence(timeout: 3))
        openEditor(in: app)
        reveal(notes, in: app)
        XCTAssertEqual(notes.value as? String, "Saved from Schedule")
        app.navigationBars["Edit Appointment"].buttons["Cancel"].tap()
        app.navigationBars.buttons["Today"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    @MainActor
    func testVisitStartFromStopPreservesAppointmentNavigationAndRelationships() {
        let app = launch("VisitFromStop-\(UUID().uuidString)")
        defer { app.terminate() }
        openAppointment("Peanut", in: app)
        app.buttons["visit-start-action"].tap()
        XCTAssertTrue(app.buttons["visit-save-progress"].waitForExistence(timeout: 3))
        app.buttons["visit-close"].tap()
        XCTAssertTrue(app.buttons["visit-resume-action"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Today"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "today-stop-row").count, 1)
        XCTAssertTrue((app.buttons["today-stop-row"].value as? String)?.contains("Thunder") == true)
        XCTAssertTrue(app.buttons["today-run-sheet-active"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Schedule"].tap()
        openSchedulePeanut(in: app)
        XCTAssertTrue(app.buttons["visit-resume-action"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["visit-start-action"].exists)
    }

    @MainActor
    func testSharedEditorSavesAndCancelsWithoutLosingTabHistory() {
        let store = "StopEditing-\(UUID().uuidString)"
        var app = launch(store)
        app.tabBars.buttons["Schedule"].tap()
        app.buttons["appointment-row-Chestnut Barn"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Today"].tap()
        openAppointment("Peanut", in: app)
        openEditor(in: app)
        XCTAssertEqual(app.buttons["appointment-barn-picker"].value as? String, "The Old Barn")
        app.buttons["appointment-horse-Thunder"].tap()
        app.navigationBars["Edit Appointment"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Thunder"].exists)

        openEditor(in: app)
        app.buttons["appointment-horse-Thunder"].tap()
        let notes = app.textViews["Appointment Notes"]
        reveal(notes, in: app)
        notes.tap()
        notes.typeText("Saved through the shared editor")
        app.buttons["appointment-keyboard-done"].tap()
        app.navigationBars["Edit Appointment"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Saved through the shared editor")).firstMatch.waitForExistence(timeout: 3))
        app.navigationBars.buttons["Today"].tap()
        let choices = app.buttons.matching(identifier: "today-stop-row")
        XCTAssertEqual(choices.count, 2)
        XCTAssertTrue(choices.matching(NSPredicate(format: "value CONTAINS %@ AND value CONTAINS %@", "Peanut", "Thunder")).firstMatch.exists)
        capture(app, "Today refreshed after shared editor save")
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
        XCTAssertTrue(app.buttons.matching(identifier: "today-stop-row").matching(NSPredicate(format: "value CONTAINS %@ AND value CONTAINS %@", "Peanut", "Thunder")).firstMatch.exists)
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Monnahey Boy"].exists)
        app.navigationBars.buttons["Schedule"].tap()
        openSchedulePeanut(in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Saved through the shared editor")).firstMatch.waitForExistence(timeout: 3))
        openEditor(in: app)
        XCTAssertEqual(app.buttons["appointment-horse-Peanut"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["appointment-horse-Thunder"].value as? String, "Selected")
        app.navigationBars["Edit Appointment"].buttons["Cancel"].tap()
        app.terminate()
        app = launch(store)
        defer { app.terminate() }
        app.tabBars.buttons["Schedule"].tap()
        openSchedulePeanut(in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Saved through the shared editor")).firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testChangingTimeSeparatesStopsAndUpdatesTheSchedule() {
        let app = launch("StopTimeEditing-\(UUID().uuidString)")
        defer { app.terminate() }
        openAppointment("Peanut", in: app)
        openEditor(in: app)
        let datePicker = app.datePickers.firstMatch
        let buttons = datePicker.buttons
        XCTAssertGreaterThan(buttons.count, 0)
        buttons.element(boundBy: buttons.count - 1).tap()
        let hour = app.pickerWheels.firstMatch
        XCTAssertTrue(hour.waitForExistence(timeout: 3), app.debugDescription)
        hour.adjust(toPickerWheelValue: "17")
        app.navigationBars["Edit Appointment"].staticTexts["Edit Appointment"].tap()
        app.navigationBars["Edit Appointment"].buttons["Save"].tap()
        let summary = app.descendants(matching: .any)["appointment-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertTrue(summary.label.contains("17:00"))
        app.navigationBars.buttons["Today"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "today-stop-row").count, 2)
        capture(app, "Today distinct times remain separate physical stops")
        app.tabBars.buttons["Schedule"].tap()
        let rows = app.buttons.matching(identifier: "appointment-row-The Old Barn")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Peanut", "17:00")).firstMatch.exists)
        XCTAssertTrue(rows.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Thunder", "16:00")).firstMatch.exists)
    }

    @MainActor
    func testSingleAppointmentStopFollowsLocationAndHorseChanges() {
        let app = launch("StopLocationEditing-\(UUID().uuidString)")
        defer { app.terminate() }
        let featured = app.buttons["today-run-sheet-scheduled"]
        XCTAssertTrue(featured.waitForExistence(timeout: 5))
        featured.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.7)).tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Monnahey Boy"].exists)
        openEditor(in: app)
        let picker = app.buttons["appointment-barn-picker"]
        for _ in 0..<2 {
            picker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let option = app.buttons.matching(NSPredicate(format: "label == %@", "The Old Barn")).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 3))
            option.tap()
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "The Old Barn"), object: picker
            )
            if XCTWaiter.wait(for: [selected], timeout: 2) == .completed { break }
        }
        XCTAssertEqual(picker.value as? String, "The Old Barn")
        XCTAssertTrue(app.buttons["appointment-horse-Peanut"].waitForExistence(timeout: 3))
        app.buttons["appointment-horse-Peanut"].tap()
        app.navigationBars["Edit Appointment"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Today"].tap()
        XCTAssertTrue(featured.label.contains("The Old Barn"))
        XCTAssertTrue((featured.value as? String)?.contains("Peanut") == true)
        XCTAssertEqual(app.buttons.matching(identifier: "today-stop-row").count, 2)
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "appointment-row-The Old Barn").count, 3)
        XCTAssertFalse(app.buttons["appointment-row-Chestnut Barn"].exists)
    }

    @MainActor
    private func openAppointment(_ horse: String, in app: XCUIApplication) {
        let choice = app.buttons.matching(identifier: "today-stop-row")
            .matching(NSPredicate(format: "value CONTAINS %@", horse)).firstMatch
        reveal(choice, in: app)
        choice.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.navigationBars["Stop Details"].exists)
    }

    @MainActor
    private func openSchedulePeanut(in app: XCUIApplication) {
        let choice = app.buttons.matching(identifier: "appointment-row-The Old Barn")
            .matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Peanut", "2 horses")).firstMatch
        reveal(choice, in: app)
        choice.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openEditor(in app: XCUIApplication) {
        app.buttons["appointment-actions-menu"].tap()
        app.buttons["appointment-edit-action"].tap()
        XCTAssertTrue(app.navigationBars["Edit Appointment"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 30 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func launch(_ store: String, dynamicType: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        if dynamicType != nil { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = store
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "today-stops"
        let now = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3_600)
        app.launchEnvironment["FARRIERFLOW_UI_TEST_NOW"] = ISO8601DateFormatter().string(from: now)
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "light"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = dynamicType
        app.launch()
        return app
    }
}
