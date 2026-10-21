import XCTest

final class TodayRunSheetUITests: XCTestCase {
    @MainActor
    func testFeaturedAppointmentBecomesDueWithoutOtherStops() {
        let app = launch(
            storeName: "TodayFeaturedBoundary-\(UUID().uuidString)",
            scenario: "today-featured-boundary", referenceHour: nil
        )
        defer { app.terminate() }
        let featured = app.buttons["today-run-sheet-scheduled"]
        XCTAssertTrue(featured.waitForExistence(timeout: 5))
        XCTAssertTrue(featured.label.hasPrefix("Next Appointment"))
        XCTAssertFalse(app.buttons["today-stop-row"].exists)
        let due = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", "Due Now"), object: featured
        )
        XCTAssertEqual(XCTWaiter.wait(for: [due], timeout: 25), .completed)
        XCTAssertTrue((featured.value as? String)?.contains("Scheduled") == true)
    }

    @MainActor
    func testPastUnfinishedStopsUseRemainingToday() {
        let app = launch(
            storeName: "TodayPastStops-\(UUID().uuidString)",
            scenario: "today-stops", referenceHour: 17
        )
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Remaining Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Later Today"].exists)
        XCTAssertTrue(app.buttons["today-run-sheet-scheduled"].label.hasPrefix("Due Now"))
        let row = app.buttons["today-stop-row"]
        XCTAssertEqual(row.value as? String, "2 horses · Scheduled, Peanut and Thunder")
        capture(app, name: "Today remaining unfinished stops")
    }

    @MainActor
    func testLabelChangesWhenScheduledStartPassesWithoutChangingTheStop() {
        let app = launch(
            storeName: "TodayLiveBoundary-\(UUID().uuidString)",
            scenario: "today-stops-boundary", referenceHour: nil
        )
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Later Today"].waitForExistence(timeout: 5))
        let row = app.buttons["today-stop-row"]
        let value = row.value as? String
        XCTAssertTrue(app.staticTexts["Remaining Today"].waitForExistence(timeout: 25))
        XCTAssertEqual(app.buttons.matching(identifier: "today-stop-row").count, 1)
        XCTAssertEqual(row.value as? String, value)
        XCTAssertTrue(value?.contains("Scheduled") == true)
    }

    @MainActor
    func testLongLocalizedMetadataWrapsWithoutClipping() {
        let app = launch(
            storeName: "TodayLongMetadata-\(UUID().uuidString)",
            scenario: "today-stops", colorScheme: "dark",
            doublesLocalizedStrings: true
        )
        defer { app.terminate() }
        let row = app.buttons["today-stop-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isHittable)
        capture(app, name: "Today metadata double length localization")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.7)).tap()
        XCTAssertTrue(app.buttons["today-stop-appointment"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "today-stop-appointment").count, 2)
        capture(app, name: "Stop Details double length localization")
        app.buttons["today-stop-appointment"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["appointment-summary"].waitForExistence(timeout: 3))
        capture(app, name: "Appointment double length localization")
    }

    @MainActor
    func testGroupedStopsPreserveAppointmentNavigationAfterRelaunch() {
        let store = "TodayGrouped-\(UUID().uuidString)"
        var app = launch(storeName: store, scenario: "today-stops")
        XCTAssertTrue(app.buttons["today-run-sheet-scheduled"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Later Today"].exists)
        XCTAssertTrue(app.staticTexts["1 stop"].exists)
        let row = app.buttons["today-stop-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.value as? String == "2 horses · Scheduled, Peanut and Thunder")
        capture(app, name: "Today compact grouped stops light")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.7)).tap()
        XCTAssertTrue(app.navigationBars["Stop Details"].waitForExistence(timeout: 3))
        let identity = app.descendants(matching: .any)["today-stop-identity"]
        XCTAssertTrue(identity.waitForExistence(timeout: 3))
        capture(app, name: "Stop Details light hierarchy")
        let choices = app.buttons.matching(identifier: "today-stop-appointment")
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(choices.count, 2)
        choices.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["appointment-summary"].exists)
        XCTAssertTrue(app.buttons["visit-start-action"].isEnabled)
        capture(app, name: "Appointment light time date and record surfaces")
        app.navigationBars.buttons["Stop Details"].tap()
        choices.element(boundBy: 1).tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        app.terminate()
        app = launch(storeName: store, scenario: "today-stops", colorScheme: "dark")
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["today-stop-row"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "today-stop-row").count, 1)
        capture(app, name: "Today compact grouped stops dark")
        app.buttons["today-stop-row"].tap()
        XCTAssertTrue(app.navigationBars["Stop Details"].waitForExistence(timeout: 3))
        capture(app, name: "Stop Details dark hierarchy")
        let darkChoice = app.buttons.matching(identifier: "today-stop-appointment").firstMatch
        XCTAssertTrue(darkChoice.waitForExistence(timeout: 3))
        darkChoice.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        capture(app, name: "Appointment dark time date and record surfaces")
    }

    @MainActor
    func testGroupedStopsAtLargestTextInDarkMode() {
        let app = launch(
            storeName: "TodayGroupedXXXL-\(UUID().uuidString)",
            scenario: "today-stops",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            colorScheme: "dark"
        )
        defer { app.terminate() }
        let featured = app.buttons["today-run-sheet-scheduled"]
        XCTAssertTrue(featured.waitForExistence(timeout: 5))
        capture(app, name: "Today featured appointment dark largest text")
        let row = app.buttons["today-stop-row"]
        for _ in 0..<6 {
            if row.exists && row.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        capture(app, name: "Today later stop dark largest text")
        row.tap()
        XCTAssertTrue(app.navigationBars["Stop Details"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(app.descendants(matching: .any)["today-stop-identity"].frame.height, 150)
        capture(app, name: "Stop Details largest text dark")
        let choices = app.buttons.matching(identifier: "today-stop-appointment")
        let choice = choices.firstMatch
        reveal(choice, in: app)
        XCTAssertEqual(choices.count, 2)
        choice.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        capture(app, name: "Appointment largest text dark identity")
        let start = app.buttons["visit-start-action"]
        reveal(start, in: app)
        XCTAssertTrue(start.isEnabled)
        capture(app, name: "Appointment largest text dark existing action")
    }

    @MainActor
    func testStopAndAppointmentHierarchyAtLargestTextInLightMode() {
        let app = launch(
            storeName: "TodayLightHierarchyXXXL-\(UUID().uuidString)",
            scenario: "today-stops",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            colorScheme: "light"
        )
        defer { app.terminate() }
        let row = app.buttons["today-stop-row"]
        XCTAssertTrue(app.buttons["today-run-sheet-scheduled"].waitForExistence(timeout: 5))
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.navigationBars["Stop Details"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(app.descendants(matching: .any)["today-stop-identity"].frame.height, 150)
        capture(app, name: "Stop Details largest text light")
        let choice = app.buttons.matching(identifier: "today-stop-appointment").firstMatch
        reveal(choice, in: app)
        choice.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        capture(app, name: "Appointment largest text light identity")
        let start = app.buttons["visit-start-action"]
        reveal(start, in: app)
        XCTAssertTrue(start.isEnabled)
        capture(app, name: "Appointment largest text light existing action")
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 {
            let tabBar = app.tabBars.firstMatch
            let bottom = tabBar.exists && tabBar.isHittable ? tabBar.frame.minY : app.frame.maxY - 24
            if element.exists && element.isHittable && element.frame.maxY < bottom { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCompletedStopsExposeWorkCompleteState() {
        let app = launch(storeName: "TodayCompletedStops-\(UUID().uuidString)")
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let completedStops = app.buttons.matching(
            NSPredicate(format: "value CONTAINS %@", "Work Complete")
        )

        XCTAssertEqual(completedStops.count, 2)
        XCTAssertTrue(completedStops.element(boundBy: 0).isHittable)
        XCTAssertTrue(completedStops.element(boundBy: 1).isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Today native status badges"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testInvoiceActionIsImmediatelyReachableAtAccessibilityXXXL() {
        let app = launch(
            storeName: "TodayAccessibilityXXXL-\(UUID().uuidString)",
            preferredContentSizeCategory:
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let action = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        XCTAssertTrue(action.isHittable)
    }

    @MainActor
    func testInvoiceContextUsesFullRowWidthAtAccessibilityXXXL() {
        let app = launch(
            storeName: "TodayInvoiceContextXXXL-\(UUID().uuidString)",
            preferredContentSizeCategory:
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let context = app.staticTexts["today-create-invoice-context"]
        XCTAssertTrue(context.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(context.frame.width, app.frame.width * 0.65)
    }

    @MainActor
    func testContextualInvoiceActionPreselectsOnlyPromotedVisit() {
        let app = launch(storeName: "TodayContextualInvoice-\(UUID().uuidString)")
        defer { app.terminate() }

        let action = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()

        XCTAssertTrue(app.navigationBars["Create Invoice"].waitForExistence(timeout: 3))
        let firstVisit = app.buttons["invoice-visit-choice-0"]
        let secondVisit = app.buttons["invoice-visit-choice-1"]
        XCTAssertTrue(firstVisit.waitForExistence(timeout: 3))
        XCTAssertTrue(secondVisit.exists)
        XCTAssertEqual(firstVisit.value as? String, "Selected")
        XCTAssertEqual(secondVisit.value as? String, "Not selected")
        XCTAssertTrue(
            accessibilityText(
                of: app.descendants(matching: .any)["invoice-selection-visit-count"]
            ).contains("1")
        )
        XCTAssertTrue(
            accessibilityText(
                of: app.descendants(matching: .any)["invoice-selection-total"]
            ).contains("50")
        )
        let generate = app.buttons["invoice-generate-action"]
        XCTAssertTrue(generate.isEnabled)

        firstVisit.tap()
        XCTAssertEqual(firstVisit.value as? String, "Not selected")
        XCTAssertFalse(generate.isEnabled)

        app.navigationBars["Create Invoice"].buttons["Today"].tap()
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        action.tap()
        XCTAssertTrue(firstVisit.waitForExistence(timeout: 3))
        XCTAssertEqual(firstVisit.value as? String, "Selected")
        XCTAssertEqual(secondVisit.value as? String, "Not selected")
    }

    @MainActor
    func testPaymentStatusIncludesInvoiceIssueDate() {
        let app = launch(
            storeName: "TodayPaymentStatus-\(UUID().uuidString)",
            scenario: "payment-pending"
        )
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["today-review-invoice-action"].waitForExistence(timeout: 3)
        )
        let context = app.staticTexts["today-review-invoice-context"]
        XCTAssertTrue(context.waitForExistence(timeout: 3))
        XCTAssertTrue(context.label.contains("Aug 17, 2026"))
        XCTAssertTrue(context.label.contains("payment pending"))
    }

    @MainActor
    private func launch(
        storeName: String,
        scenario: String = "invoice-ready",
        preferredContentSizeCategory: String? = nil,
        colorScheme: String? = nil,
        referenceHour: Int? = 12,
        doublesLocalizedStrings: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = scenario
        if let preferredContentSizeCategory {
            XCTAssertEqual(
                preferredContentSizeCategory,
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
            )
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] =
                "accessibility5"
        }
        if scenario == "today-stops", let referenceHour,
           let referenceDate = Calendar.current.date(
               bySettingHour: referenceHour, minute: 0, second: 0, of: .now
           ) {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_NOW"] = ISO8601DateFormatter().string(from: referenceDate)
        }
        if doublesLocalizedStrings {
            app.launchArguments += ["-NSDoubleLocalizedStrings", "YES"]
        }
        if let colorScheme {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = colorScheme
        }
        app.launch()
        return app
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
