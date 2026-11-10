import XCTest

final class InvoiceFlowUITests: XCTestCase {
    @MainActor
    func testSelectAllTogglesSelectionAndTracksIndividualVisits() {
        continueAfterFailure = false
        let app = launch(storeName: "InvoiceSelectAll-\(UUID().uuidString)")
        defer { app.terminate() }
        let create = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        let all = app.switches["invoice-select-all-action"]
        let first = app.buttons["invoice-visit-choice-0"]
        let second = app.buttons["invoice-visit-choice-1"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(all.frame.height, 44)
        XCTAssertTrue(second.exists)

        all.tap()
        XCTAssertEqual(all.value as? String, "Selected", app.debugDescription)
        XCTAssertEqual(first.value as? String, "Selected")
        XCTAssertEqual(second.value as? String, "Selected")
        XCTAssertTrue(app.buttons["invoice-generate-action"].isEnabled)
        XCTAssertTrue(accessibilityText(of: app.descendants(matching: .any)["invoice-selection-visit-count"].firstMatch).contains("2"))
        let selected = XCTAttachment(screenshot: app.screenshot())
        selected.name = "Create Invoice all selected"
        selected.lifetime = .keepAlways
        add(selected)

        all.tap()
        XCTAssertEqual(all.value as? String, "Not selected")
        XCTAssertEqual(first.value as? String, "Not selected")
        XCTAssertEqual(second.value as? String, "Not selected")
        XCTAssertFalse(app.buttons["invoice-generate-action"].isEnabled)
        XCTAssertTrue(accessibilityText(of: app.descendants(matching: .any)["invoice-selection-visit-count"].firstMatch).contains("0"))
        let cleared = XCTAttachment(screenshot: app.screenshot())
        cleared.name = "Create Invoice all deselected"
        cleared.lifetime = .keepAlways
        add(cleared)

        first.tap()
        XCTAssertEqual(all.value as? String, "Not selected")
        XCTAssertEqual(first.value as? String, "Selected")
        XCTAssertEqual(second.value as? String, "Not selected")
        all.tap()
        XCTAssertEqual(second.value as? String, "Selected")
        second.tap()
        XCTAssertEqual(second.value as? String, "Not selected")
        all.tap()
        XCTAssertEqual(second.value as? String, "Selected")
        all.tap()
        XCTAssertFalse(app.buttons["invoice-generate-action"].isEnabled)
    }

    @MainActor
    func testSelectAllIsHiddenWithOneEligibleVisit() {
        continueAfterFailure = false
        let app = launch(storeName: "InvoiceSingleVisit-\(UUID().uuidString)")
        defer { app.terminate() }
        let create = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        XCTAssertTrue(app.switches["invoice-select-all-action"].waitForExistence(timeout: 5))
        let first = app.buttons["invoice-visit-choice-0"]
        if first.value as? String != "Selected" { first.tap() }
        app.buttons["invoice-generate-action"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["invoice-detail-0001"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["invoice-visit-choice-1"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["invoice-select-all-action"].exists)
        if first.value as? String == "Selected" { first.tap() }
        XCTAssertFalse(app.buttons["invoice-generate-action"].isEnabled)
        first.tap()
        XCTAssertEqual(first.value as? String, "Selected")
        XCTAssertTrue(app.buttons["invoice-generate-action"].isEnabled)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Create Invoice with one visit and no Select All"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testSelectAllToggleAtLargestTextInDarkMode() {
        continueAfterFailure = false
        let app = launch(
            storeName: "InvoiceSelectAllLarge-\(UUID().uuidString)",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            colorScheme: "dark"
        )
        defer { app.terminate() }
        let create = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        let all = app.switches["invoice-select-all-action"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertTrue(all.isHittable)
        all.tap()
        XCTAssertEqual(all.value as? String, "Selected")
        XCTAssertTrue(app.buttons["invoice-generate-action"].isEnabled)
        let selected = XCTAttachment(screenshot: app.screenshot())
        selected.name = "Create Invoice native selection at largest text dark"
        selected.lifetime = .keepAlways
        add(selected)
        all.tap()
        XCTAssertEqual(all.value as? String, "Not selected")
        XCTAssertFalse(app.buttons["invoice-generate-action"].isEnabled)
    }

    @MainActor
    func testShortInvoiceDeletionConfirmationCancelsWithoutChangingInvoice() {
        continueAfterFailure = false
        let app = launch(storeName: "InvoiceDeleteCopy-\(UUID().uuidString)")
        defer { app.terminate() }
        let create = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        let first = app.buttons["invoice-visit-choice-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        selectAllVisits(firstVisit: first, in: app)
        app.buttons["invoice-generate-action"].tap()
        let more = app.buttons["invoice-more-actions"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let delete = app.buttons["invoice-delete-action"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let alert = app.alerts["Delete Invoice?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@",
            "Any recorded payment will also be deleted. Your work and photos will stay."
        )).firstMatch.exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Short invoice deletion confirmation"
        capture.lifetime = .keepAlways
        add(capture)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["invoice-detail-0001"].exists)
        XCTAssertTrue(accessibilityText(of: app.descendants(matching: .any)["invoice-detail-total"]).contains("$100.00"))
    }

    @MainActor
    func testMarkUnpaidKeepsConfirmationCancellationAndPersistence() {
        verifyMarkUnpaid(colorScheme: "light")
    }

    @MainActor
    func testMarkUnpaidMenuInDarkAppearance() {
        verifyMarkUnpaid(colorScheme: "dark")
    }

    @MainActor
    private func verifyMarkUnpaid(colorScheme: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "InvoiceUnpaidStyle-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "invoice-ready"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = colorScheme
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }

        let create = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        let visit = app.buttons["invoice-visit-choice-0"]
        XCTAssertTrue(visit.waitForExistence(timeout: 5))
        if !accessibilityText(of: visit).contains("Selected") { visit.tap() }
        app.buttons["invoice-generate-action"].tap()

        let markPaid = app.buttons["invoice-mark-paid-action"]
        XCTAssertTrue(markPaid.waitForExistence(timeout: 5))
        markPaid.tap()
        XCTAssertTrue(app.navigationBars["Record Payment"].waitForExistence(timeout: 3))
        app.buttons["payment-method-picker"].tap()
        let cash = app.buttons["Cash"]
        XCTAssertTrue(cash.waitForExistence(timeout: 3))
        cash.tap()
        app.buttons["payment-confirm"].tap()
        XCTAssertTrue(app.staticTexts["Status, Paid"].waitForExistence(timeout: 5))

        let more = app.buttons["invoice-more-actions"]
        more.tap()
        let markUnpaid = app.buttons["invoice-mark-unpaid-action"]
        XCTAssertTrue(markUnpaid.waitForExistence(timeout: 3))
        XCTAssertTrue(markUnpaid.isEnabled)
        let menuCapture = XCTAttachment(screenshot: app.screenshot())
        menuCapture.name = "Neutral Mark as Unpaid menu \(colorScheme)"
        menuCapture.lifetime = .keepAlways
        add(menuCapture)
        markUnpaid.tap()

        let confirmation = app.alerts["Mark Invoice Unpaid?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmation.staticTexts[
            "This clears the recorded payment and marks the invoice as unpaid."
        ].exists)
        let confirmationCapture = XCTAttachment(screenshot: app.screenshot())
        confirmationCapture.name = "Neutral payment reversal confirmation \(colorScheme)"
        confirmationCapture.lifetime = .keepAlways
        add(confirmationCapture)
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Status, Paid"].exists)

        more.tap()
        XCTAssertTrue(markUnpaid.waitForExistence(timeout: 3))
        markUnpaid.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["invoice-mark-unpaid-confirmation"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Status, Unpaid"].waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(app.buttons["invoice-delete-action"].waitForExistence(timeout: 3))
        XCTAssertFalse(markUnpaid.exists)
        let deleteCapture = XCTAttachment(screenshot: app.screenshot())
        deleteCapture.name = "Destructive Delete Invoice menu \(colorScheme)"
        deleteCapture.lifetime = .keepAlways
        add(deleteCapture)

        app.terminate()
        app.launch()
        openInvoices(in: app)
        let invoice = app.buttons["invoice-row-0001"]
        XCTAssertTrue(invoice.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: invoice).contains("Unpaid"))
    }

    @MainActor
    func testPaymentSheetHasContentOnEveryPresentation() {
        continueAfterFailure = false
        let app = launch(storeName: "PaymentFirstPresentation-\(UUID())")
        defer { app.terminate() }
        let create = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        let visit = app.buttons["invoice-visit-choice-0"]
        XCTAssertTrue(visit.waitForExistence(timeout: 5))
        if !accessibilityText(of: visit).contains("Selected") { visit.tap() }
        app.buttons["invoice-generate-action"].tap()
        let paid = app.buttons["invoice-mark-paid-action"]
        XCTAssertTrue(paid.waitForExistence(timeout: 5))
        for index in 0..<3 {
            paid.tap()
            XCTAssertTrue(app.navigationBars["Record Payment"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["payment-method-picker"].exists)
            XCTAssertTrue(app.buttons["payment-confirm"].exists)
            if index == 0 {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "First payment presentation contains form"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            app.navigationBars["Record Payment"].buttons["Cancel"].tap()
            XCTAssertTrue(paid.waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testInvoiceToolbarKeepsPrimaryActionsAtTopAndDeleteInMore() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "InvoiceToolbar-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "app-store-showcase"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "full"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }

        openClients(in: app)
        openInvoices(in: app)
        let invoice = app.buttons["invoice-row-0148"]
        XCTAssertTrue(invoice.waitForExistence(timeout: 5))
        invoice.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["invoice-detail-0148"]
                .waitForExistence(timeout: 5)
        )
        let markPaid = app.buttons["invoice-mark-paid-action"]
        let share = app.buttons["invoice-share-pdf-action"]
        let more = app.buttons["invoice-more-actions"]
        XCTAssertTrue(markPaid.waitForExistence(timeout: 3))
        XCTAssertTrue(share.waitForExistence(timeout: 3))
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        XCTAssertLessThan(markPaid.frame.midY, app.frame.height * 0.2)

        more.tap()
        XCTAssertTrue(app.buttons["Delete Invoice"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Delete Invoice"].waitForNonExistence(timeout: 3))

        markPaid.tap()
        XCTAssertTrue(app.navigationBars["Record Payment"].waitForExistence(timeout: 3))
    }

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
    func testGBPCurrencyFlowsThroughInvoicePaymentAndLockedBusinessUI() {
        let app = launch(
            storeName: "InvoiceGBP-\(UUID().uuidString)",
            currencyCode: "GBP",
            localeIdentifier: "en_GB"
        )
        defer { app.terminate() }

        let createInvoice = app.buttons["today-create-invoice-action"]
        XCTAssertTrue(createInvoice.waitForExistence(timeout: 3))
        createInvoice.tap()

        let firstVisit = app.buttons["invoice-visit-choice-0"]
        XCTAssertTrue(firstVisit.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: firstVisit).contains("£50.00"))
        selectAllVisits(firstVisit: firstVisit, in: app)
        XCTAssertTrue(
            accessibilityText(
                of: app.descendants(matching: .any)["invoice-selection-total"]
            ).contains("£100.00")
        )
        app.buttons["invoice-generate-action"].tap()

        let detail = app.descendants(matching: .any)["invoice-detail-0001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(
            accessibilityText(
                of: app.descendants(matching: .any)["invoice-detail-total"]
            ).contains("£100.00")
        )
        app.buttons["invoice-mark-paid-action"].tap()
        XCTAssertTrue(app.navigationBars["Record Payment"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityText(of: app.descendants(matching: .any)["payment-amount"])
                .contains("£100.00")
        )
        app.navigationBars["Record Payment"].buttons["Cancel"].tap()

        app.navigationBars["Invoice 0001"].buttons.firstMatch.tap()
        openClients(in: app)
        for _ in 0..<2 where !app.buttons["Business Profile"].exists {
            app.openBusinessRoot()
            _ = app.buttons["Business Profile"].waitForExistence(timeout: 2)
        }
        app.buttons["Business Profile"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["business-profile-currency-locked"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["business-profile-currency-picker"].exists)
    }

    @MainActor
    func testInvoiceFlowPersistsPaidSnapshotHistoryAcrossRelaunch() throws {
        let app = launch(storeName: "InvoiceFlow-\(UUID().uuidString)")
        defer { app.terminate() }

        openClients(in: app)
        let invoices = app.buttons["Invoices"]
        for _ in 0..<2 where !invoices.exists {
            app.openBusinessRoot()
            _ = invoices.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(invoices.exists)
        XCTAssertTrue(app.buttons["Business Profile"].exists)
        openInvoices(in: app)
        XCTAssertTrue(app.staticTexts["No Invoices"].waitForExistence(timeout: 3))
        let invoicesBackButton = app.tabBars.buttons["Clients"]
        invoicesBackButton.tap()

        let clientRow = app.buttons["client-row-Invoice Client"]
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
        XCTAssertTrue(app.buttons["invoice-share-pdf-action"].exists)
        let markPaid = app.buttons["invoice-mark-paid-action"]
        XCTAssertTrue(markPaid.waitForExistence(timeout: 3))
        XCTAssertTrue(markPaid.isHittable)
        XCTAssertLessThan(markPaid.frame.midY, app.frame.height * 0.2)
        let moreActions = app.buttons["invoice-more-actions"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 3))
        moreActions.tap()
        XCTAssertTrue(app.buttons["Delete Invoice"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Delete Invoice"].waitForNonExistence(timeout: 3))
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
        XCTAssertTrue(
            app.descendants(matching: .any)["invoice-first-payment-hint"].exists
        )

        markPaid.tap()
        XCTAssertTrue(app.navigationBars["Record Payment"].waitForExistence(timeout: 3))
        let method = app.buttons["payment-method-picker"]
        XCTAssertTrue(method.waitForExistence(timeout: 3))
        let bankTransfer = app.buttons["Bank Transfer"]
        for _ in 0..<2 where !bankTransfer.exists {
            method.tap()
            _ = bankTransfer.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(bankTransfer.exists)
        bankTransfer.tap()
        let reference = app.textFields["payment-reference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 3))
        let appFrame = app.frame
        let referenceFrame = reference.frame
        app.coordinate(
            withNormalizedOffset: CGVector(
                dx: referenceFrame.midX / appFrame.width,
                dy: referenceFrame.midY / appFrame.height
            )
        ).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("BANK-UI-42")
        XCTAssertEqual(reference.value as? String, "BANK-UI-42")
        app.buttons["payment-confirm"].tap()
        let paidStatus = app.staticTexts["Status, Paid"].firstMatch
        for _ in 0..<6 where !paidStatus.exists {
            detail.swipeDown()
        }
        XCTAssertTrue(paidStatus.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["invoice-share-pdf-action"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["invoice-mark-paid-action"].exists)
        XCTAssertFalse(app.buttons["invoice-delete-action"].exists)
        let methodDetail = app.staticTexts.matching(identifier: "invoice-payment-details")
            .matching(NSPredicate(format: "label CONTAINS %@", "Bank Transfer"))
            .firstMatch
        let referenceDetail = app.staticTexts.matching(identifier: "invoice-payment-details")
            .matching(NSPredicate(format: "label CONTAINS %@", "BANK-UI-42"))
            .firstMatch
        for _ in 0..<4 where !methodDetail.exists { detail.swipeUp() }
        XCTAssertTrue(methodDetail.waitForExistence(timeout: 3))
        XCTAssertTrue(referenceDetail.waitForExistence(timeout: 3))
        detail.tap()

        app.navigationBars.buttons["Client"].tap()
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
        app.selectFarrierFlowTab("Clients")
        app.buttons["client-row-Invoice Client"].tap()
        XCTAssertTrue(app.buttons["client-invoice-0001"].waitForExistence(timeout: 3))
        app.buttons["horse-row-Milo"].tap()
        let history = app.descendants(matching: .any)["horse-history-visit-Milo"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()
        XCTAssertTrue(
            app.staticTexts["This visit has invoiced work. Corrections do not change saved invoices."]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.buttons["visit-detail-actions"].exists)
        XCTAssertTrue(app.buttons["visit-invoice-0001"].waitForExistence(timeout: 3))
        app.buttons["visit-invoice-0001"].tap()
        let paidMoreActions = app.buttons["invoice-more-actions"]
        XCTAssertTrue(paidMoreActions.waitForExistence(timeout: 3))
        paidMoreActions.tap()
        let markUnpaid = app.buttons["invoice-mark-unpaid-action"]
        XCTAssertTrue(markUnpaid.waitForExistence(timeout: 3))
        markUnpaid.tap()
        let correction = app.alerts["Mark Invoice Unpaid?"]
        XCTAssertTrue(correction.waitForExistence(timeout: 3))
        correction.buttons["invoice-mark-unpaid-confirmation"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Status, Unpaid"].waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.descendants(matching: .any)["invoice-first-payment-hint"].exists
        )

        app.terminate()
        app.launch()
        openClients(in: app)
        openInvoices(in: app)
        let correctedRow = app.buttons["invoice-row-0001"]
        XCTAssertTrue(correctedRow.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: correctedRow).contains("Unpaid"))
    }

    @MainActor
    func testFullScreenPhotographExposesHorsePositionAndCreatedDate() {
        let app = launch(storeName: "PhotographAccessibility-\(UUID().uuidString)")
        defer { app.terminate() }

        openClients(in: app)
        app.buttons["client-row-Invoice Client"].tap()
        app.buttons["horse-row-Milo"].tap()
        let history = app.descendants(matching: .any)["horse-history-visit-Milo"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()

        let photographs = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Photos")
        ).firstMatch
        XCTAssertTrue(photographs.waitForExistence(timeout: 3))
        photographs.tap()
        let thumbnail = app.buttons["Photo 1 of 1"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 3))
        thumbnail.tap()

        let fullImage = app.images.matching(
            NSPredicate(
                format: "label BEGINSWITH %@",
                "Photo for Milo, 1 of 1, created "
            )
        ).firstMatch
        XCTAssertTrue(fullImage.waitForExistence(timeout: 3))
        XCTAssertTrue(fullImage.isHittable)
        XCTAssertTrue(app.navigationBars["Milo · 1 of 1"].exists)
    }

    @MainActor
    private func launch(
        storeName: String,
        preferredContentSizeCategory: String? = nil,
        currencyCode: String = "USD",
        localeIdentifier: String = "en_US",
        colorScheme: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "invoice-ready"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_BUSINESS_CURRENCY"] = currencyCode
        if let colorScheme {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = colorScheme
        }
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", localeIdentifier,
        ]
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
        if app.navigationBars["Invoices"].exists { return }
        app.openBusinessRoot()
        let invoices = app.buttons["Invoices"]
        XCTAssertTrue(invoices.waitForExistence(timeout: 3))
        invoices.tap()
        XCTAssertTrue(app.navigationBars["Invoices"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func selectAllVisits(
        firstVisit: XCUIElement,
        in app: XCUIApplication
    ) {
        let selectAll = app.switches["invoice-select-all-action"]
        if selectAll.value as? String != "Selected" {
            selectAll.tap()
        }
        XCTAssertEqual(selectAll.value as? String, "Selected")
        XCTAssertEqual(firstVisit.value as? String, "Selected")
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
