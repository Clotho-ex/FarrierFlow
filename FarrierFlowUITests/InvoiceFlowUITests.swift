import XCTest

final class InvoiceFlowUITests: XCTestCase {
    @MainActor
    func testInvoiceEntryRemainsUsableAtLargeDynamicType() {
        let app = launch(
            storeName: "InvoiceLargeType-\(UUID().uuidString)",
            preferredContentSizeCategory:
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        defer { app.terminate() }

        let createInvoice = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(createInvoice.waitForExistence(timeout: 3))
        XCTAssertTrue(createInvoice.isHittable)
        XCTAssertTrue(accessibilityText(of: createInvoice).contains("Create Invoice"))
        createInvoice.tap()

        let firstVisit = app.buttons["invoice-visit-choice-0"]
        if !firstVisit.waitForExistence(timeout: 3), createInvoice.exists {
            createInvoice.tap()
        }
        XCTAssertTrue(firstVisit.waitForExistence(timeout: 5))
        XCTAssertTrue(firstVisit.isHittable)
        XCTAssertTrue(accessibilityText(of: firstVisit).contains("Invoice Service Location"))
        XCTAssertTrue(accessibilityText(of: firstVisit).contains("50"))
        if !accessibilityText(of: firstVisit).contains("Selected") {
            firstVisit.tap()
        }
        XCTAssertTrue(accessibilityText(of: firstVisit).contains("Selected"))

        let generate = app.buttons["invoice-generate-action"]
        XCTAssertTrue(generate.isEnabled)
        generate.tap()

        let detail = app.descendants(matching: .any)["invoice-detail-0001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["invoice-native-detail-content"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["invoice-detail-amount-due"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Milo"].exists)
        XCTAssertTrue(app.staticTexts["Trim"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "50")
        ).firstMatch.exists)
        let lineItem = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Milo, Trim")
        ).firstMatch
        XCTAssertTrue(lineItem.waitForExistence(timeout: 3))
        XCTAssertFalse(lineItem.label.contains("50"))
        XCTAssertTrue((lineItem.value as? String)?.contains("50") == true)
    }

    @MainActor
    func testInvoiceFlowPersistsPaidSnapshotHistoryAcrossRelaunch() throws {
        let app = launch(storeName: "InvoiceFlow-\(UUID().uuidString)")
        defer { app.terminate() }

        openClients(in: app)
        let invoices = app.buttons["Invoices"]
        for _ in 0..<2 where !invoices.exists {
            app.buttons["More"].tap()
            _ = invoices.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(invoices.exists)
        XCTAssertTrue(app.buttons["My Business"].exists)
        openInvoices(in: app)
        XCTAssertTrue(app.staticTexts["No Invoices"].waitForExistence(timeout: 3))
        let invoicesBackButton = app.navigationBars.buttons["Clients"]
        invoicesBackButton.tap()

        let clientRow = app.staticTexts["client-row-Invoice Client"]
        if !clientRow.waitForExistence(timeout: 2), invoicesBackButton.exists {
            invoicesBackButton.tap()
        }
        XCTAssertTrue(clientRow.waitForExistence(timeout: 3))
        clientRow.tap()
        app.buttons["client-create-invoice-action"].tap()
        let firstVisit = app.buttons["invoice-visit-choice-0"]
        let secondVisit = app.buttons["invoice-visit-choice-1"]
        XCTAssertTrue(firstVisit.waitForExistence(timeout: 3))
        XCTAssertTrue(secondVisit.exists)
        XCTAssertTrue(accessibilityText(of: firstVisit).contains("Invoice Service Location"))
        XCTAssertTrue(accessibilityText(of: firstVisit).contains("50"))
        selectAllVisits(firstVisit: firstVisit, in: app)
        XCTAssertTrue(accessibilityText(of: secondVisit).contains("Selected"))
        XCTAssertTrue(
            accessibilityText(
                of: app.descendants(matching: .any)["invoice-selection-visit-count"]
            ).contains("2")
        )
        XCTAssertTrue(
            accessibilityText(
                of: app.descendants(matching: .any)["invoice-selection-service-count"]
            ).contains("2")
        )
        XCTAssertTrue(
            accessibilityText(
                of: app.descendants(matching: .any)["invoice-selection-total"]
            ).contains("100")
        )
        XCTAssertTrue(app.buttons["invoice-generate-action"].isEnabled)
        app.buttons["invoice-generate-action"].tap()

        let detail = app.descendants(matching: .any)["invoice-detail-0001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        let actionsMenu = app.buttons["invoice-actions-menu"]
        XCTAssertTrue(actionsMenu.exists)
        XCTAssertFalse(app.buttons["invoice-preview-pdf-action"].exists)
        XCTAssertTrue(app.staticTexts["Milo"].exists)
        XCTAssertTrue(app.staticTexts["Trim"].exists)
        XCTAssertFalse(app.staticTexts["Scout"].exists)
        let total = app.descendants(matching: .any)["invoice-detail-total"]
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: total).contains("100"))

        let nativeInvoiceScreenshot = XCTAttachment(screenshot: app.screenshot())
        nativeInvoiceScreenshot.name = "Native Invoice Detail"
        nativeInvoiceScreenshot.lifetime = .keepAlways
        add(nativeInvoiceScreenshot)

        for _ in 0..<3 where !app.staticTexts["Test Farrier"].exists {
            detail.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["UI Test Farrier"].waitForExistence(timeout: 3))
        for _ in 0..<3 where !app.staticTexts["Invoice Client"].exists {
            detail.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Invoice Client"].waitForExistence(timeout: 3))
        actionsMenu.tap()
        XCTAssertTrue(app.buttons["invoice-share-pdf-action"].waitForExistence(timeout: 3))
        let markPaid = app.buttons["invoice-mark-paid-action"]
        XCTAssertTrue(markPaid.exists)
        XCTAssertTrue(app.buttons["invoice-delete-action"].exists)

        markPaid.tap()
        let markPaidAlert = app.alerts["Mark Invoice Paid?"]
        XCTAssertTrue(markPaidAlert.waitForExistence(timeout: 3))
        markPaidAlert.buttons.matching(
            identifier: "invoice-mark-paid-confirmation"
        ).firstMatch.tap()
        let paidStatus = app.staticTexts["Status, Paid"].firstMatch
        for _ in 0..<6 where !paidStatus.exists {
            detail.swipeDown()
        }
        XCTAssertTrue(paidStatus.waitForExistence(timeout: 3))
        actionsMenu.tap()
        XCTAssertTrue(app.buttons["invoice-share-pdf-action"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["invoice-mark-paid-action"].exists)
        XCTAssertFalse(app.buttons["invoice-delete-action"].exists)
        detail.tap()

        app.navigationBars.buttons["Invoice Client"].tap()
        XCTAssertTrue(
            app.buttons["client-create-invoice-action"]
                .waitForNonExistence(timeout: 3)
        )

        app.terminate()
        app.launch()

        openClients(in: app)
        openInvoices(in: app)
        let row = app.buttons["invoice-row-0001"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: row).contains("Paid"))
        XCTAssertTrue(
            accessibilityText(of: row).contains(
                String(Calendar.current.component(.year, from: Date()))
            )
        )
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
    func testFullScreenPhotographExposesHorsePositionAndCreatedDate() {
        let app = launch(storeName: "PhotographAccessibility-\(UUID().uuidString)")
        defer { app.terminate() }

        openClients(in: app)
        app.staticTexts["client-row-Invoice Client"].tap()
        app.staticTexts["horse-row-Milo"].tap()
        let history = app.descendants(matching: .any)["horse-history-visit-Milo"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()

        let photographs = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Hoof Photos")
        ).firstMatch
        XCTAssertTrue(photographs.waitForExistence(timeout: 3))
        photographs.tap()
        let thumbnail = app.buttons["Photo 1 of 1"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 3))
        thumbnail.tap()

        let fullImage = app.images.matching(
            NSPredicate(
                format: "label BEGINSWITH %@",
                "Hoof photo for Milo, 1 of 1, created "
            )
        ).firstMatch
        XCTAssertTrue(fullImage.waitForExistence(timeout: 3))
        XCTAssertTrue(fullImage.isHittable)
        XCTAssertTrue(app.navigationBars["Milo · 1 of 1"].exists)
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
    private func openClients(in app: XCUIApplication) {
        for _ in 0..<2 {
            app.tabBars.buttons["Clients"].tap()
            if app.navigationBars["Clients"].waitForExistence(timeout: 2) {
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
    private func selectAllVisits(
        firstVisit: XCUIElement,
        in app: XCUIApplication
    ) {
        let selectAll = app.buttons["invoice-select-all-action"]
        for _ in 0..<2 {
            selectAll.tap()
            if firstVisit.value as? String == "Selected" {
                return
            }
        }
        XCTFail("Select All did not select the eligible Visits")
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
