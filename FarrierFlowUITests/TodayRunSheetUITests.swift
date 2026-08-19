import XCTest

final class TodayRunSheetUITests: XCTestCase {
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
        preferredContentSizeCategory: String? = nil
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
