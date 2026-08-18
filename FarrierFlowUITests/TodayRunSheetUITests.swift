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
}
