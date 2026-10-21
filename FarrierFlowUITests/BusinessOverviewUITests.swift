import XCTest

final class BusinessOverviewUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testOutstandingOpensUnpaidInvoicesAndPaymentRefreshesTheBalance() {
        let app = launch()
        defer { app.terminate() }
        verifyOutstanding("£150.00", count: "2 unpaid invoices", in: app)
        let outstandingFrame = app.buttons["business-outstanding"].frame
        let completedFrame = app.buttons["business-completed-visits"].frame
        XCTAssertLessThan(outstandingFrame.maxX, completedFrame.minX)
        XCTAssertEqual(outstandingFrame.minY, completedFrame.minY, accuracy: 1)
        XCTAssertEqual(outstandingFrame.width, completedFrame.width, accuracy: 1)
        capture(app, "Business Overview side by side")
        app.buttons["business-outstanding"].tap()
        XCTAssertTrue(app.navigationBars["Unpaid Invoices"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["invoice-row-0002"].exists)
        app.buttons["invoice-row-0001"].tap()
        XCTAssertTrue(app.navigationBars["Invoice 0001"].waitForExistence(timeout: 3))
        app.buttons["invoice-mark-paid-action"].tap()
        XCTAssertTrue(app.navigationBars["Record Payment"].waitForExistence(timeout: 3))
        app.buttons["payment-method-picker"].tap()
        app.buttons["Cash"].tap()
        app.buttons["payment-confirm"].tap()
        XCTAssertTrue(app.navigationBars["Invoice 0001"].waitForExistence(timeout: 3))
        app.navigationBars["Invoice 0001"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Unpaid Invoices"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["invoice-row-0001"].exists)
        XCTAssertTrue(app.buttons["invoice-row-0002"].exists)
        app.openBusinessRoot()
        verifyOutstanding("£50.00", count: "1 unpaid invoice", in: app)
        capture(app, "Business GBP balance after payment")

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.openBusinessRoot()
        verifyOutstanding("£50.00", count: "1 unpaid invoice", in: app)
        let allInvoices = app.buttons["Invoices"]
        reveal(allInvoices, in: app)
        allInvoices.tap()
        XCTAssertTrue(app.navigationBars["Invoices"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["invoice-row-0001"].exists)
        XCTAssertTrue(app.buttons["invoice-row-0002"].exists)
    }

    @MainActor
    func testCompletedVisitDetailsAndDeletionRefreshCountWithoutChangingInvoiceSnapshots() {
        let app = launch()
        defer { app.terminate() }
        let completed = app.buttons["business-completed-visits"]
        reveal(completed, in: app)
        XCTAssertTrue(completed.label.contains("2"), completed.label)
        completed.tap()
        XCTAssertTrue(app.navigationBars["Completed Visits"].waitForExistence(timeout: 3))
        let rows = visitRows(in: app)
        XCTAssertEqual(rows.count, 2)
        capture(app, "Current month completed visits")
        rows.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        app.buttons["visit-delete-action"].tap()
        let confirm = app.buttons["visit-delete-confirmation"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Completed Visits"].waitForExistence(timeout: 5))
        XCTAssertEqual(visitRows(in: app).count, 1)
        app.openBusinessRoot()
        reveal(completed, in: app)
        XCTAssertTrue(completed.label.contains("1"), completed.label)
        verifyOutstanding("£150.00", count: "2 unpaid invoices", in: app)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.openBusinessRoot()
        reveal(completed, in: app)
        XCTAssertTrue(completed.label.contains("1"), completed.label)
    }

    @MainActor
    func testOverviewAtLargestTextInDarkModePreservesReadOnlyRecordAccess() {
        let app = launch(readOnly: true, largestText: true)
        defer { app.terminate() }
        verifyOutstanding("£150.00", count: "2 unpaid invoices", in: app)
        capture(app, "Business Overview largest text dark")
        let completed = app.buttons["business-completed-visits"]
        let outstanding = app.buttons["business-outstanding"]
        XCTAssertGreaterThan(completed.frame.minY, outstanding.frame.maxY)
        XCTAssertEqual(completed.frame.width, outstanding.frame.width, accuracy: 1)
        reveal(completed, in: app)
        completed.tap()
        XCTAssertTrue(app.navigationBars["Completed Visits"].waitForExistence(timeout: 3))
        visitRows(in: app).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["visit-detail-accessibility-overview"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["visit-edit-action"].exists)
        XCTAssertFalse(app.buttons["visit-delete-action"].exists)
        capture(app, "Existing read-only Visit detail")
    }

    @MainActor
    func testEmptyOverviewShowsNumericZeroAndUsefulEmptyDestinations() {
        let app = launch(empty: true)
        defer { app.terminate() }
        verifyOutstanding("$0.00", count: "0 unpaid invoices", in: app)
        XCTAssertFalse(app.buttons["business-outstanding"].label.contains("Complimentary"))
        app.buttons["business-outstanding"].tap()
        XCTAssertTrue(app.navigationBars["Unpaid Invoices"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Unpaid Invoices"].exists)
        app.openBusinessRoot()
        app.buttons["business-completed-visits"].tap()
        XCTAssertTrue(app.navigationBars["Completed Visits"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Completed Visits"].exists)
    }

    @MainActor
    private func launch(readOnly: Bool = false, largestText: Bool = false, empty: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "BusinessOverview-\(UUID())"
        if !empty { app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending" }
        app.launchEnvironment["FARRIERFLOW_UI_TEST_BUSINESS_CURRENCY"] = "GBP"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = readOnly ? "read-only" : "full"
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        // The business currency must remain GBP even when the device's locale is US English.
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.openBusinessRoot()
        return app
    }

    @MainActor
    private func verifyOutstanding(_ amount: String, count: String, in app: XCUIApplication) {
        let outstanding = app.buttons["business-outstanding"]
        reveal(outstanding, in: app)
        XCTAssertTrue(outstanding.label.contains(amount), outstanding.label)
        XCTAssertTrue(outstanding.label.contains(count), outstanding.label)
    }

    @MainActor
    private func visitRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "business-completed-visit-"))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
