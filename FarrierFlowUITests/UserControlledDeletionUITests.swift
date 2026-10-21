import XCTest

final class UserControlledDeletionUITests: XCTestCase {
    @MainActor
    func testInvoicedVisitCanBeCorrectedAndDeletedWhileInvoiceRemains() {
        let app = launch()
        defer { app.terminate() }
        openClient(in: app)
        app.buttons["horse-row-Milo"].tap()
        let history = app.buttons["horse-history-visit-Milo"].firstMatch
        reveal(history, in: app)
        history.tap()
        let edit = app.buttons["visit-edit-action"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()
        let outcome = app.buttons["visit-outcome-Milo"]
        XCTAssertTrue(outcome.waitForExistence(timeout: 3))
        outcome.tap()
        app.buttons["Not Serviced"].tap()
        let clear = app.buttons["Clear Recorded Work"]
        if clear.waitForExistence(timeout: 2) { clear.tap() }
        let save = app.buttons["visit-save-correction"]
        XCTAssertTrue(save.isEnabled, "An all-Not-Serviced correction must be savable")
        save.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        let invoice = app.buttons["visit-invoice-0001"]
        reveal(invoice, in: app)
        invoice.tap()
        XCTAssertTrue(app.navigationBars["Invoice 0001"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Trim"].exists, "The saved invoice keeps its original work snapshot")
        app.navigationBars.buttons["Visit"].tap()
        app.buttons["visit-delete-action"].tap()
        let confirm = app.buttons["visit-delete-confirmation"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["visit-edit-action"].exists)
        app.buttons["visit-delete-action"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Milo"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "horse-history-visit-Milo").count, 1, "The other completed visit remains")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openClient(in: app)
        let kept = app.buttons["client-invoice-0001"]
        reveal(kept, in: app)
        kept.tap()
        XCTAssertTrue(app.navigationBars["Invoice 0001"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Trim"].exists)
    }

    @MainActor
    func testPaidInvoiceCanBeDeletedUsingSheetWithoutDeletingHorseOrVisit() {
        let app = launch()
        defer { app.terminate() }
        openClient(in: app)
        let row = app.buttons["client-invoice-0001"]
        reveal(row, in: app)
        row.tap()
        app.buttons["invoice-mark-paid-action"].tap()
        XCTAssertTrue(app.buttons["payment-method-picker"].waitForExistence(timeout: 3))
        app.buttons["payment-method-picker"].tap()
        app.buttons["Cash"].tap()
        app.buttons["payment-confirm"].tap()
        XCTAssertTrue(app.staticTexts["Status, Paid"].waitForExistence(timeout: 3))
        app.buttons["invoice-more-actions"].tap()
        app.buttons["invoice-delete-action"].tap()
        let confirm = app.buttons["invoice-delete-confirmation"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Invoice 0001"].exists)
        app.buttons["invoice-more-actions"].tap()
        app.buttons["invoice-delete-action"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["client-invoice-0001"].exists)
        app.buttons["horse-row-Milo"].tap()
        let history = app.buttons["horse-history-visit-Milo"].firstMatch
        reveal(history, in: app)
        XCTAssertTrue(history.exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openClient(in: app)
        XCTAssertFalse(app.buttons["client-invoice-0001"].exists)
        XCTAssertTrue(app.buttons["horse-row-Milo"].exists)
    }

    @MainActor
    func testFailedDeletionShowsErrorAfterSheetAndKeepsRecordsForRetry() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "FailedDeletion-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DELETE_FAILURE"] = "1"
        app.launch()
        defer { app.terminate() }
        openClient(in: app)
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        let confirm = app.buttons["client-delete-confirmation"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        let alert = app.alerts["Couldn’t Delete Record"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.exists)
        XCTAssertTrue(alert.staticTexts["Nothing was deleted. Your records and photos are unchanged. Try again."].exists)
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["horse-row-Milo"].exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_DELETE_FAILURE")
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openClient(in: app)
        XCTAssertTrue(app.buttons["horse-row-Milo"].exists)
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["client-row-Invoice Client"].exists)
        app.openBusinessRoot()
        app.buttons["Invoices"].tap()
        XCTAssertTrue(app.buttons["invoice-row-0001"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "UserDeletion-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launch()
        return app
    }

    @MainActor
    private func openClient(in app: XCUIApplication) {
        app.tabBars.buttons["Clients"].tap()
        let row = app.buttons["client-row-Invoice Client"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
