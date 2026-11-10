import XCTest

final class UserControlledDeletionUITests: XCTestCase {
    @MainActor
    func testScheduleRemovalKeepsRecordedWorkAndInvoiceUntilExplicitWorkDeletion() {
        let app = launch()
        defer { app.terminate() }
        openClient(in: app)
        app.buttons["horse-row-Milo"].tap()
        let history = app.buttons["horse-history-visit-Milo"].firstMatch
        reveal(history, in: app)
        history.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        app.buttons["visit-detail-actions"].tap()
        app.buttons["visit-delete-action"].tap()
        let confirm = app.buttons["visit-delete-confirmation"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["visit-detail-actions"].exists)
        app.buttons["visit-detail-actions"].tap()
        app.buttons["visit-delete-action"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Milo"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "horse-history-visit-Milo").count, 2)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openClient(in: app)
        app.buttons["horse-row-Milo"].tap()
        reveal(history, in: app)
        history.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Trim"].firstMatch.exists)
        app.buttons["visit-detail-actions"].tap()
        XCTAssertTrue(app.buttons["visit-edit-action"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["visit-delete-action"].exists)
        app.tap()
        app.openBusinessRoot()
        let recordedWork = app.buttons["business-recorded-work"]
        reveal(recordedWork, in: app)
        recordedWork.tap()
        XCTAssertTrue(app.navigationBars["Recorded Work"].waitForExistence(timeout: 3))
        let workRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "business-completed-visit-"))
        let before = workRows.count
        XCTAssertEqual(before, 2)
        workRows.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        app.buttons["visit-detail-actions"].tap()
        let deletion = app.buttons["Delete Recorded Work"]
        XCTAssertTrue(deletion.waitForExistence(timeout: 3))
        deletion.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        capture(app, "Explicit Recorded Work deletion")
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Recorded Work"].waitForExistence(timeout: 5))
        XCTAssertEqual(workRows.count, before - 1)
        app.terminate()
        app.launch()
        openClient(in: app)
        let invoice = app.buttons["client-invoice-0001"]
        reveal(invoice, in: app)
        invoice.tap()
        XCTAssertTrue(app.navigationBars["Invoice 0001"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Trim"].exists)
        capture(app, "Invoice intact after schedule and Recorded Work deletion")
    }

    @MainActor
    func testRecordedWorkDeletionReturnsToListWithoutAnUnavailableError() {
        let app = launch()
        defer { app.terminate() }
        app.openBusinessRoot()
        let recordedWork = app.buttons["business-recorded-work"]
        reveal(recordedWork, in: app)
        recordedWork.tap()
        XCTAssertTrue(app.navigationBars["Recorded Work"].waitForExistence(timeout: 5))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "business-completed-visit-"))
        let count = rows.count
        XCTAssertGreaterThan(count, 0)
        rows.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        app.buttons["visit-detail-actions"].tap()
        app.buttons["visit-delete-action"].tap()
        let confirmation = app.alerts["Delete Recorded Work?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmation.staticTexts["You can’t recover this work or its photos. The appointment and saved invoices will stay."].exists)
        capture(app, "Native Recorded Work deletion confirmation")
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Visit"].exists)
        app.buttons["visit-detail-actions"].tap()
        app.buttons["visit-delete-action"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["visit-delete-confirmation"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Recorded Work"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Visit Unavailable"].exists)
        XCTAssertEqual(rows.count, count - 1)
        capture(app, "Recorded Work returns to list without a load error")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.openBusinessRoot()
        reveal(recordedWork, in: app)
        recordedWork.tap()
        XCTAssertTrue(app.navigationBars["Recorded Work"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, count - 1)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPaidInvoiceCanBeDeletedUsingNativeAlertWithoutDeletingHorseOrVisit() {
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
        let confirm = app.buttons["invoice-delete-confirmation"].firstMatch
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
    func testFailedDeletionShowsErrorAfterConfirmationAndKeepsRecordsForRetry() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "FailedDeletion-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DELETE_FAILURE"] = "1"
        app.launch()
        defer { app.terminate() }
        openClient(in: app)
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        let confirm = app.buttons["client-delete-confirmation"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        let alert = app.alerts["Couldn’t Delete"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.exists)
        XCTAssertTrue(alert.staticTexts["Your records and photos are unchanged. Please try again."].exists)
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
        app.selectFarrierFlowTab("Clients")
        let row = app.buttons["client-row-Invoice Client"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 5))
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
