import XCTest

final class InvoiceFlowUITests: XCTestCase {
    @MainActor
    func testInvoiceEntryRemainsUsableAtLargeDynamicType() {
        let app = launch(
            storeName: "InvoiceLargeType-\(UUID().uuidString)",
            preferredContentSizeCategory: "UICTContentSizeCategoryXXXL"
        )
        defer { app.terminate() }

        openClients(in: app)
        let client = app.staticTexts["client-row-Invoice Client"]
        XCTAssertTrue(client.waitForExistence(timeout: 3))
        XCTAssertTrue(client.isHittable)
        XCTAssertTrue(accessibilityText(of: client).contains("Invoice Client"))
        client.tap()

        let createInvoice = app.buttons["client-create-invoice-action"]
        XCTAssertTrue(createInvoice.waitForExistence(timeout: 3))
        XCTAssertTrue(createInvoice.isHittable)
        XCTAssertTrue(accessibilityText(of: createInvoice).contains("Create Invoice"))
        createInvoice.tap()

        let addBusinessProfile = app.buttons["Add Business Profile"]
        XCTAssertTrue(addBusinessProfile.waitForExistence(timeout: 3))
        XCTAssertTrue(addBusinessProfile.isHittable)
    }

    @MainActor
    func testInvoiceFlowPersistsPaidSnapshotHistoryAcrossRelaunch() throws {
        let app = launch(storeName: "InvoiceFlow-\(UUID().uuidString)")
        defer { app.terminate() }

        openClients(in: app)
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Invoices"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Business Profile"].exists)
        openInvoices(in: app)
        XCTAssertTrue(app.staticTexts["No Invoices"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()

        app.staticTexts["client-row-Invoice Client"].tap()
        app.buttons["client-create-invoice-action"].tap()
        let profileName = app.textFields["business-profile-name-field"]
        XCTAssertTrue(app.buttons["Add Business Profile"].waitForExistence(timeout: 3))
        openBusinessProfile(profileNameField: profileName, in: app)
        focusAndType("Test Farrier", in: profileName)
        app.buttons["business-profile-save-action"].tap()

        let firstVisit = app.buttons["invoice-visit-choice-0"]
        let secondVisit = app.buttons["invoice-visit-choice-1"]
        XCTAssertTrue(firstVisit.waitForExistence(timeout: 3))
        XCTAssertTrue(secondVisit.exists)
        app.buttons["invoice-select-all-action"].tap()
        XCTAssertTrue(accessibilityText(of: firstVisit).contains("Selected"))
        XCTAssertTrue(accessibilityText(of: secondVisit).contains("Selected"))
        XCTAssertTrue(app.buttons["invoice-generate-action"].isEnabled)
        app.buttons["invoice-generate-action"].tap()

        let detail = app.descendants(matching: .any)["invoice-detail-0001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Test Farrier"].exists)
        XCTAssertTrue(app.staticTexts["Invoice Client"].exists)
        XCTAssertTrue(app.staticTexts["Milo"].exists)
        XCTAssertTrue(app.staticTexts["Trim"].exists)
        XCTAssertFalse(app.staticTexts["Scout"].exists)
        let total = app.descendants(matching: .any)["invoice-detail-total"]
        for _ in 0..<3 where !total.exists {
            detail.swipeUp()
        }
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: total).contains("100"))

        app.buttons["invoice-share-pdf-action"].tap()
        let closeShareSheet = app.buttons["Close"]
        XCTAssertTrue(closeShareSheet.waitForExistence(timeout: 10))
        closeShareSheet.tap()
        XCTAssertTrue(closeShareSheet.waitForNonExistence(timeout: 5))
        app.buttons["invoice-share-pdf-action"].tap()
        XCTAssertTrue(closeShareSheet.waitForExistence(timeout: 10))
        closeShareSheet.tap()
        XCTAssertTrue(closeShareSheet.waitForNonExistence(timeout: 5))

        app.buttons["invoice-mark-paid-action"].tap()
        app.buttons.matching(identifier: "invoice-mark-paid-confirmation").firstMatch.tap()
        let paidStatus = app.staticTexts["Status, Paid"].firstMatch
        for _ in 0..<3 where !paidStatus.exists {
            detail.swipeDown()
        }
        XCTAssertTrue(paidStatus.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["invoice-delete-action"].exists)

        app.navigationBars.buttons["Invoice Client"].tap()
        app.buttons["client-create-invoice-action"].tap()
        XCTAssertTrue(
            app.staticTexts["No completed, uninvoiced work is available for this client."]
                .waitForExistence(timeout: 3)
        )

        app.terminate()
        app.launch()

        openClients(in: app)
        openInvoices(in: app)
        let row = app.buttons["invoice-row-0001"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: row).contains("Paid"))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["invoice-detail-0001"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Status, Paid"].exists)

        app.navigationBars.buttons["Invoices"].tap()
        app.navigationBars.buttons["Clients"].tap()
        app.staticTexts["client-row-Invoice Client"].tap()
        app.staticTexts["horse-row-Milo"].tap()
        let history = app.descendants(matching: .any)["horse-history-visit-Milo"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()
        XCTAssertTrue(
            app.staticTexts["This visit has invoiced work and can no longer be corrected."]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["visit-edit-action"].exists)
    }

    @MainActor
    private func launch(
        storeName: String,
        preferredContentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "invoice-ready"
        if let preferredContentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                preferredContentSizeCategory,
            ]
        }
        app.launch()
        return app
    }

    @MainActor
    private func focusAndType(_ text: String, in element: XCUIElement) {
        guard element.waitForExistence(timeout: 3) else {
            XCTFail("Expected text field to exist before typing")
            return
        }
        element.tap()
        element.typeText(text)
    }

    @MainActor
    private func openBusinessProfile(
        profileNameField: XCUIElement,
        in app: XCUIApplication
    ) {
        for _ in 0..<2 {
            app.buttons["Add Business Profile"].tap()
            if profileNameField.waitForExistence(timeout: 2) {
                return
            }
        }
        XCTFail("Business Profile editor did not open")
    }

    @MainActor
    private func openClients(in app: XCUIApplication) {
        for _ in 0..<2 {
            app.tabBars.buttons["Clients"].tap()
            if app.buttons["More"].waitForExistence(timeout: 2) {
                return
            }
        }
        XCTFail("Clients tab did not open")
    }

    @MainActor
    private func openInvoices(in app: XCUIApplication) {
        for _ in 0..<2 {
            if app.navigationBars["Invoices"].exists {
                return
            }
            if app.buttons["Invoices"].waitForExistence(timeout: 1) {
                app.buttons["Invoices"].tap()
                if app.navigationBars["Invoices"].waitForExistence(timeout: 2) {
                    return
                }
            }
            if app.buttons["More"].waitForExistence(timeout: 1) {
                app.buttons["More"].tap()
            }
        }
        XCTFail("Invoices did not open")
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
