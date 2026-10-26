import XCTest

final class VisitHistoryAccessibilityUITests: XCTestCase {
    @MainActor
    func testInvoicedVisitOverviewSurfacesServiceLocationAtAccessibilityXXXL() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "VisitHistoryAccessibility-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] =
            "accessibility5"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }

        guard openInvoicedVisit(in: app) else { return }

        let overview = app.descendants(matching: .any)[
            "visit-detail-work-dates"
        ].firstMatch
        guard overview.waitForExistence(timeout: 3) else {
            XCTFail("Accessibility Visit overview did not appear")
            return
        }
        XCTAssertTrue(bringIntoView(overview, in: app))
        let overviewText = accessibilityText(of: overview)
        XCTAssertTrue(overviewText.contains("Started"))
        XCTAssertTrue(overviewText.contains("Finished"))
        XCTAssertFalse(overviewText.contains("Completed"))
        let status = app.staticTexts["visit-detail-status"]
        XCTAssertTrue(bringIntoView(status, in: app, towardTop: true))
        XCTAssertEqual(status.label, "Completed")
        let notice = app.descendants(matching: .any)["visit-invoice-warning"].firstMatch
        XCTAssertTrue(bringIntoView(notice, in: app))
        XCTAssertTrue(accessibilityText(of: notice).contains("invoiced work"))
        XCTAssertTrue(accessibilityText(of: notice).contains("Corrections do not change saved invoices"))
        capture("Prominent invoiced work notice AX dark", in: app)

        let serviceLocation = app.descendants(matching: .any)[
            "visit-detail-service-location-snapshot"
        ].firstMatch
        XCTAssertTrue(bringIntoView(serviceLocation, in: app, towardTop: true))
        XCTAssertTrue(
            accessibilityText(of: serviceLocation).contains(
                "Invoice Service Location"
            )
        )
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Visit history accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let horseResult = app.descendants(matching: .any)[
            "visit-result-Milo"
        ].firstMatch
        XCTAssertTrue(bringIntoView(horseResult, in: app))
        XCTAssertTrue(accessibilityText(of: horseResult).contains("Serviced"))
        XCTAssertLessThan(horseResult.frame.height, app.frame.height)
        let resultScreenshot = XCTAttachment(screenshot: app.screenshot())
        resultScreenshot.name = "Visit result accessibility XXXL"
        resultScreenshot.lifetime = .keepAlways
        add(resultScreenshot)
    }

    @MainActor
    func testDefaultInvoicedVisitKeepsDetailedSummary() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "VisitHistoryDefault-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launch()
        defer { app.terminate() }

        guard openInvoicedVisit(in: app) else { return }

        let status = app.staticTexts["visit-detail-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: status).contains("Completed"))
        let notice = app.descendants(matching: .any)["visit-invoice-warning"].firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: notice).contains("This visit has invoiced work."))
        XCTAssertTrue(accessibilityText(of: notice).contains("Corrections do not change saved invoices."))
        let dates = app.descendants(matching: .any)["visit-detail-work-dates"].firstMatch
        XCTAssertTrue(dates.exists)
        XCTAssertTrue(accessibilityText(of: dates).contains("Started"))
        XCTAssertTrue(accessibilityText(of: dates).contains("Finished"))

        let serviceLocation = app.descendants(matching: .any)[
            "visit-detail-service-location-snapshot"
        ].firstMatch
        XCTAssertTrue(serviceLocation.waitForExistence(timeout: 3))
        XCTAssertTrue(serviceLocation.isHittable)
        XCTAssertGreaterThan(status.frame.minX, serviceLocation.frame.maxX)
        XCTAssertLessThan(abs(status.frame.midY - serviceLocation.frame.minY), 40)
        XCTAssertEqual(app.staticTexts.matching(identifier: "visit-detail-status").count, 1)

        XCTAssertFalse(app.staticTexts["Work Date"].exists)
        XCTAssertFalse(app.staticTexts["Service Location"].exists)
        XCTAssertFalse(app.staticTexts["Services"].exists)
        XCTAssertFalse(app.staticTexts["Subtotal"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Visit history default Dynamic Type"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testCompletedVisitKeepsNotesServicesTotalAndInvoiceLinksAfterRelaunch() {
        verifyCompletedNotes(largestText: false)
    }

    @MainActor
    func testCompletedWorkNotesRemainReadableAtLargestTextInDarkMode() {
        verifyCompletedNotes(largestText: true)
    }

    @MainActor
    private func verifyCompletedNotes(largestText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "CompletedCleanup-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        defer { app.terminate() }
        guard openInvoicedVisit(in: app) else { return }
        app.buttons["visit-detail-actions"].tap()
        XCTAssertTrue(app.buttons["visit-edit-action"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["visit-delete-action"].exists)
        capture("Completed Visit native actions menu", in: app)
        app.buttons["visit-edit-action"].tap()
        guard app.staticTexts["visit-correction-invoice-warning"].waitForExistence(timeout: 5) else {
            capture("Correction editor did not open", in: app)
            XCTFail("The correction editor did not open after Edit")
            return
        }
        let toggle = app.buttons["visit-work-notes-toggle-Milo"]
        XCTAssertTrue(bringIntoView(toggle, in: app))
        toggle.tap()
        let editor = app.descendants(matching: .any)["visit-work-notes-Milo"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        let note = "Gate code 1428. Front shoes checked; use the rear gate and keep the horse in the shaded aisle."
        XCTAssertTrue(bringIntoView(editor, in: app))
        editor.typeText(note)
        app.buttons["visit-dismiss-keyboard"].tap()
        app.buttons["visit-save-correction"].tap()
        XCTAssertTrue(app.buttons["visit-detail-actions"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        guard openInvoicedVisit(in: app) else { return }
        let notes = app.descendants(matching: .any)["visit-result-notes-Milo"].firstMatch
        XCTAssertTrue(bringIntoView(notes, in: app))
        XCTAssertTrue(accessibilityText(of: notes).contains(note))
        let photos = app.buttons["visit-result-photographs-Milo"]
        if largestText {
            XCTAssertTrue(bringIntoView(photos, in: app, towardTop: true))
            XCTAssertTrue(bringIntoView(notes, in: app))
        } else {
            XCTAssertLessThan(photos.frame.maxY, notes.frame.minY + 1)
        }
        capture("Prominent completed Work Notes AX \(largestText)", in: app)
        let scout = app.descendants(matching: .any)["visit-result-Scout"].firstMatch
        XCTAssertTrue(bringIntoView(scout, in: app))
        XCTAssertTrue(accessibilityText(of: scout).contains("Serviced"))
        let total = app.descendants(matching: .any)["visit-detail-total"].firstMatch
        XCTAssertTrue(bringIntoView(total, in: app))
        XCTAssertTrue(accessibilityText(of: total).contains("$100.00"))
        XCTAssertTrue(accessibilityText(of: total).contains("Total recorded work"))
        XCTAssertFalse(app.staticTexts["Subtotal"].exists)
        capture("Completed Visit single total and invoices", in: app)
        let invoice = app.buttons["visit-invoice-0001"]
        XCTAssertTrue(bringIntoView(invoice, in: app))
        invoice.tap()
        XCTAssertTrue(app.staticTexts["invoice-detail-total"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["invoice-detail-total"].label.contains("$100.00"))
    }

    @MainActor
    func testReadOnlyCompletedVisitHidesEmptyPhotosAndKeepsExistingPhotos() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "ReadOnlyVisitPhotos-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        guard openInvoicedVisit(in: app) else { return }
        let photos = app.buttons["visit-result-photographs-Milo"]
        XCTAssertTrue(bringIntoView(photos, in: app))
        XCTAssertTrue(photos.label.contains("1 photos"))
        photos.tap()
        XCTAssertTrue(app.buttons["Photo 1 of 1"].waitForExistence(timeout: 5))
        app.navigationBars["Photos"].buttons.firstMatch.tap()
        let scout = app.descendants(matching: .any)["visit-result-Scout"].firstMatch
        XCTAssertTrue(bringIntoView(scout, in: app))
        let total = app.descendants(matching: .any)["visit-detail-total"].firstMatch
        XCTAssertTrue(bringIntoView(total, in: app))
        XCTAssertFalse(app.buttons["visit-result-photographs-Scout"].exists)
        XCTAssertFalse(app.buttons["visit-detail-actions"].exists)
        capture("Read-only Visit omits empty Photos", in: app)
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openInvoicedVisit(in app: XCUIApplication) -> Bool {
        guard openClients(in: app) else {
            XCTFail("Clients tab did not open")
            return false
        }
        let client = app.buttons["client-row-Invoice Client"]
        guard client.waitForExistence(timeout: 5) else {
            XCTFail("Invoice Client did not appear")
            return false
        }
        client.tap()

        let horse = app.buttons["horse-row-Milo"]
        guard bringIntoView(horse, in: app) else {
            XCTFail("Milo did not appear")
            return false
        }
        horse.tap()

        let history = app.descendants(matching: .any)[
            "horse-history-visit-Milo"
        ].firstMatch
        guard bringIntoView(history, in: app) else {
            XCTFail("Milo's Visit history did not appear")
            return false
        }
        let historyText = accessibilityText(of: history)
        XCTAssertTrue(historyText.contains("Serviced"))
        XCTAssertTrue(historyText.contains("service"))
        XCTAssertTrue(historyText.contains("View Visit"))
        XCTAssertFalse(historyText.contains("Work Notes"))
        XCTAssertFalse(historyText.contains("Subtotal"))
        history.tap()

        guard app.navigationBars["Visit"].waitForExistence(timeout: 3) else {
            XCTFail("Visit detail did not open")
            return false
        }
        return true
    }

    @MainActor
    private func openClients(in app: XCUIApplication) -> Bool {
        for _ in 0..<3 {
            app.tabBars.buttons["Clients"].tap()
            if app.navigationBars["Clients"].waitForExistence(timeout: 2) {
                return true
            }
        }
        return false
    }

    @MainActor
    private func bringIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication,
        towardTop: Bool = false
    ) -> Bool {
        for _ in 0..<10 {
            let top = app.navigationBars.allElementsBoundByIndex.map { $0.frame.maxY }.max() ?? 100
            if element.exists, element.isHittable,
               element.frame.midY > top, element.frame.midY < app.frame.maxY - 90 {
                return true
            }
            if (element.exists && element.frame.midY <= top) || (!element.exists && towardTop) {
                app.swipeDown()
            } else { app.swipeUp() }
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
