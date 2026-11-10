import XCTest

final class FieldWorkflowRefinementUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testClientAndInvoiceSearchKeepNativeRecordNavigation() {
        verifySearch(largestText: false)
    }

    @MainActor
    func testSearchAndAppointmentActionsAtLargestTextInDarkMode() {
        verifySearch(largestText: true)
    }

    @MainActor
    func testAppointmentSafetyAndDatesFollowThePhoneRegion() {
        for region in ["en_US", "en_GB"] {
            let app = launch(region: region)
            app.selectFarrierFlowTab("Schedule")
            let appointment = app.buttons["appointment-row-Willow Creek Stables"].firstMatch
            reveal(appointment, in: app)
            appointment.tap()
            let time = app.staticTexts["appointment-summary-time"]
            XCTAssertTrue(time.waitForExistence(timeout: 5), app.debugDescription)
            let date = app.staticTexts.matching(NSPredicate(
                format: "label CONTAINS %@", region == "en_US" ? "October 27" : "27 October"
            )).firstMatch
            XCTAssertTrue(date.exists, app.debugDescription)
            let hasMeridiem = time.label.range(of: #"\b(AM|PM)\b"#, options: .regularExpression) != nil
            XCTAssertEqual(hasMeridiem, region == "en_US", time.label)
            capture("Appointment date and time — \(region)")
            let safety = app.descendants(matching: .any)["appointment-safety-Atlas"].firstMatch
            reveal(safety, in: app)
            XCTAssertTrue(safety.label.contains("Safety note for Atlas"))
            XCTAssertTrue(safety.label.contains("watch the right-front flare"))
            XCTAssertFalse(app.descendants(matching: .any)["appointment-call-Atlas"].firstMatch.exists)
            capture("Appointment safety without phone — \(region)")
            app.terminate()
        }
    }

    @MainActor
    func testStopIdentityAndDirectionsRemainSeparateAccessibleElements() {
        for largestText in [false, true] {
            let app = launch(largestText: largestText, scenario: "today-stops")
            app.selectFarrierFlowTab("Schedule")
            let row = app.buttons["appointment-row-The Old Barn"].firstMatch
            reveal(row, in: app)
            row.tap()
            XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
            let identity = app.descendants(matching: .any)["appointment-summary"].firstMatch
            XCTAssertTrue(identity.label.contains("The Old Barn"))
            XCTAssertTrue(identity.label.contains("4:00"))
            let directions = app.descendants(matching: .any)["appointment-detail-address"].firstMatch
            reveal(directions, in: app)
            XCTAssertTrue(directions.elementType == .link || directions.elementType == .button)
            XCTAssertTrue(directions.label.contains("Directions to 120 Meadow Road"))
            XCTAssertTrue(directions.isHittable)
            capture("Stop identity and directions \(largestText ? "AX dark" : "light")")
            app.terminate()
        }
    }

    @MainActor
    private func verifySearch(largestText: Bool) {
        let app = launch(largestText: largestText)
        defer { app.terminate() }
        app.selectFarrierFlowTab("Clients")
        search("Atlas", in: app)
        let jordan = app.buttons["client-row-Jordan Ellis"]
        XCTAssertTrue(jordan.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["client-row-Morgan Reed"].exists)
        capture("Client search by horse \(largestText ? "AX dark" : "light")")
        search("missing customer", in: app)
        XCTAssertFalse(jordan.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "No Results")).firstMatch.waitForExistence(timeout: 3))
        search("014-1182", in: app)
        XCTAssertTrue(jordan.waitForExistence(timeout: 3))
        jordan.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Contact"].exists)
        app.openBusinessRoot()
        reveal(app.buttons["Invoices"], in: app)
        app.buttons["Invoices"].tap()
        XCTAssertTrue(app.navigationBars["Invoices"].waitForExistence(timeout: 3))
        search("Jordan", in: app)
        XCTAssertTrue(app.buttons["invoice-row-0148"].waitForExistence(timeout: 3))
        search("0148", in: app)
        capture("Invoice search \(largestText ? "AX dark" : "light")")
        app.buttons["invoice-row-0148"].tap()
        XCTAssertTrue(app.buttons["invoice-share-pdf-action"].waitForExistence(timeout: 3))
        app.selectFarrierFlowTab("Schedule")
        let appointment = app.buttons["appointment-row-Oak Ridge Farm"]
        reveal(appointment, in: app)
        appointment.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        let startVisit = app.buttons["visit-start-action"]
        if largestText { reveal(startVisit, in: app) }
        XCTAssertTrue(startVisit.isHittable)
        capture("Appointment primary action \(largestText ? "AX dark" : "light")")
        let directions = app.descendants(matching: .any)["appointment-detail-address"].firstMatch
        reveal(directions, in: app)
        XCTAssertTrue(directions.elementType == .link || directions.elementType == .button)
        XCTAssertTrue(directions.label.contains("Directions to"))
        XCTAssertGreaterThanOrEqual(directions.frame.height, 44)
        capture("Appointment native directions \(largestText ? "AX dark" : "light")")
        XCTAssertFalse(app.descendants(matching: .any)["appointment-call-Milo"].firstMatch.exists)
        capture("Appointment horse card without phone \(largestText ? "AX dark" : "light")")
    }

    @MainActor
    func testDirtyCreationDraftsResistAccidentalSheetDismissal() {
        let app = launch()
        defer { app.terminate() }
        app.selectFarrierFlowTab("Clients")
        app.navigationBars["Clients"].buttons["Add Client"].tap()
        type("Draft Customer", into: app.textFields["client-name-field"], in: app)
        dismissKeyboard("client-keyboard-done", in: app)
        attemptSheetDismissal(in: app)
        XCTAssertEqual(app.textFields["client-name-field"].value as? String, "Draft Customer")
        app.navigationBars["New Client"].buttons["Save"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        capture("Client saved after protected swipe")
        XCTAssertTrue(app.navigationBars["New Client"].waitForNonExistence(timeout: 3), app.debugDescription)
        search("Draft Customer", in: app)
        let client = app.buttons["client-row-Draft Customer"]
        XCTAssertTrue(client.waitForExistence(timeout: 3))
        client.tap()
        app.buttons["Add Horse"].tap()
        type("Draft Horse", into: app.textFields["horse-name-field"], in: app)
        dismissKeyboard("horse-keyboard-done", in: app)
        attemptSheetDismissal(in: app)
        XCTAssertEqual(app.textFields["horse-name-field"].value as? String, "Draft Horse")
        app.buttons["horse-barn-picker"].tap()
        app.buttons["Create New Service Location"].tap()
        type("Draft Barn", into: app.textFields["barn-name-field"], in: app)
        dismissKeyboard("barn-keyboard-done", in: app)
        app.buttons["barn-more-details"].tap()
        let notes = app.textViews["barn-contact-notes-field"]
        type("Gate code 1234", into: notes, in: app)
        dismissKeyboard("barn-keyboard-done", in: app)
        attemptSheetDismissal(in: app)
        XCTAssertTrue(app.navigationBars["New Service Location"].exists)
        XCTAssertEqual(notes.value as? String, "Gate code 1234")
        capture("Arrival notes with native keyboard dismissal")
        app.navigationBars["New Service Location"].buttons["Cancel"].tap()
        if app.navigationBars["Select Service Location"].exists {
            app.navigationBars["Select Service Location"].buttons.firstMatch.tap()
        }
        app.navigationBars["New Horse"].buttons["Cancel"].tap()
        app.selectFarrierFlowTab("Schedule")
        app.navigationBars["Schedule"].buttons["Schedule Appointment"].tap()
        app.buttons["appointment-barn-picker"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Oak Ridge Farm"].tap()
        app.buttons["appointment-horse-Milo"].tap()
        attemptSheetDismissal(in: app)
        XCTAssertTrue(app.navigationBars["New Appointment"].exists)
        XCTAssertEqual(app.buttons["appointment-horse-Milo"].value as? String, "Selected")
        app.navigationBars["New Appointment"].buttons["Cancel"].tap()
        app.openBusinessRoot()
        reveal(app.buttons["Services"], in: app)
        app.buttons["Services"].tap()
        app.buttons["service-add-action"].tap()
        type("Draft Service", into: app.textFields["service-name-field"], in: app)
        dismissKeyboard("service-keyboard-done", in: app)
        attemptSheetDismissal(in: app)
        XCTAssertTrue(app.navigationBars["New Service"].exists)
        XCTAssertEqual(app.textFields["service-name-field"].value as? String, "Draft Service")
        app.navigationBars["New Service"].buttons["Cancel"].tap()
    }

    @MainActor
    func testServiceChoicesRemainReadableAndCancellableAtLargestText() {
        let app = launch(largestText: true)
        defer { app.terminate() }
        app.buttons["today-run-sheet-active"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        let context = app.descendants(matching: .any)["visit-horse-toggle-Atlas"].firstMatch
        reveal(context, in: app)
        XCTAssertTrue(context.label.contains("Jordan Ellis"))
        XCTAssertTrue(context.label.contains("watch the right-front flare"))
        capture("Active visit saved owner and handling notes at largest text")
        let add = app.buttons["visit-add-service-Atlas"]
        reveal(add, in: app)
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Service"].waitForExistence(timeout: 3))
        let trim = app.buttons["visit-service-option-Trim"]
        reveal(trim, in: app)
        XCTAssertTrue(trim.label.contains("$55.00"))
        capture("Service name and price at largest text in dark mode")
        reveal(app.buttons["visit-create-service-action"], in: app)
        XCTAssertTrue(app.buttons["visit-create-service-action"].isEnabled)
        app.navigationBars["Add Service"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["visit-unsaved-state"].exists)
    }

    @MainActor
    func testPaymentKeyboardDismissalKeepsUnconfirmedDetailsAndInvoiceUnpaid() {
        let app = launch()
        defer { app.terminate() }
        app.openBusinessRoot()
        app.buttons["Invoices"].tap()
        app.buttons["invoice-row-0148"].tap()
        app.buttons["invoice-mark-paid-action"].tap()
        XCTAssertTrue(app.navigationBars["Record Payment"].waitForExistence(timeout: 3))
        let reference = app.textFields["payment-reference"]
        type("Bank receipt 456", into: reference, in: app)
        dismissKeyboard("payment-keyboard-done", in: app)
        let note = app.descendants(matching: .any)["payment-note"].firstMatch
        type("Customer supplied a receipt", into: note, in: app)
        dismissKeyboard("payment-keyboard-done", in: app)
        XCTAssertEqual(reference.value as? String, "Bank receipt 456")
        XCTAssertEqual(note.value as? String, "Customer supplied a receipt")
        XCTAssertFalse(app.buttons["payment-confirm"].isEnabled)
        capture("Payment details retain draft after keyboard dismissal")
        app.navigationBars["Record Payment"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["invoice-mark-paid-action"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCreateServiceWhileReplacingWorkPreservesIndependentDraftAndPriceKeyboard() {
        let app = launch()
        defer { app.terminate() }
        app.buttons["today-run-sheet-active"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5), app.debugDescription)
        let work = app.buttons["visit-work-item-Atlas-Full Set"]
        reveal(work, in: app)
        work.tap()
        XCTAssertTrue(app.navigationBars["Edit Visit Service"].waitForExistence(timeout: 3))
        type("0", into: app.textFields["work-item-price-field"], in: app)
        dismissKeyboard("work-item-keyboard-done", in: app)
        app.buttons["visit-replace-service"].tap()
        XCTAssertTrue(app.buttons["visit-service-option-Trim"].waitForExistence(timeout: 3))
        let create = app.buttons["visit-create-service-action"]
        reveal(create, in: app)
        create.tap()
        type("Field Correction", into: app.textFields["service-name-field"], in: app)
        type("75", into: app.textFields["service-price-field"], in: app)
        dismissKeyboard("service-keyboard-done", in: app)
        app.navigationBars["New Service"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        let replacement = app.buttons["visit-work-item-Atlas-Field Correction"]
        reveal(replacement, in: app)
        XCTAssertFalse(app.buttons["visit-work-item-Atlas-Full Set"].exists)
        XCTAssertTrue(app.buttons["visit-save-progress"].isEnabled)
        capture("New service replaces only the selected horse work")
        app.buttons["visit-save-progress"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Delete Visit"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.alerts.firstMatch.exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["visit-unsaved-state"].waitForNonExistence(timeout: 3))
        app.buttons["visit-close"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForNonExistence(timeout: 3), app.debugDescription)
        app.terminate()
        app.launch()
        app.buttons["today-run-sheet-active"].tap()
        reveal(app.buttons["visit-work-item-Atlas-Field Correction"], in: app)
        let beacon = app.buttons["visit-horse-toggle-Beacon"]
        reveal(beacon, in: app)
        beacon.tap()
        reveal(app.buttons["visit-work-item-Beacon-Front Shoes"], in: app)
        XCTAssertTrue(app.buttons["visit-work-item-Beacon-Front Shoes"].exists)
    }

    @MainActor
    private func launch(largestText: Bool = false, scenario: String = "app-store-showcase", region: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", region]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "FieldAudit-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["FARRIERFLOW_UI_TEST_NOW"] = "2026-10-27T12:00:00Z"
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func search(_ query: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 2) { app.swipeDown() }
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let previous = field.value as? String ?? ""
        if !previous.isEmpty, previous != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(query)
    }

    @MainActor
    private func type(_ value: String, into field: XCUIElement, in app: XCUIApplication) {
        reveal(field, in: app)
        for point in [CGVector(dx: 0.5, dy: 0.5), CGVector(dx: 0.85, dy: 0.5), CGVector(dx: 0.5, dy: 0.75), CGVector(dx: 0.5, dy: 0.85)] {
            field.coordinate(withNormalizedOffset: point).tap()
            let focus = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            if XCTWaiter.wait(for: [focus], timeout: 2) == .completed {
                field.typeText(value)
                return
            }
        }
        capture("Input focus failure")
        XCTFail("Expected keyboard focus for \(field.identifier)")
    }

    @MainActor
    private func dismissKeyboard(_ id: String, in app: XCUIApplication) {
        let done = app.buttons[id]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }

    @MainActor
    private func attemptSheetDismissal(in app: XCUIApplication) {
        for _ in 0..<2 {
            let grabber = app.buttons.matching(identifier: "Sheet Grabber").allElementsBoundByIndex.last(where: \.isHittable)
            guard let handle = grabber ?? app.navigationBars.allElementsBoundByIndex.last(where: \.isHittable) else {
                XCTFail("Expected a native sheet handle")
                return
            }
            handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<24 {
            let top = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.maxY }.max() ?? 100
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY
                : app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
            if element.exists, element.isHittable, element.frame.midY > top + 4, element.frame.midY < bottom - 4 { return }
            let surface = app.collectionViews.allElementsBoundByIndex.last(where: \.isHittable) ?? app
            let down = element.exists && element.frame.midY < top
            // Native Form bounds include rows obscured by the keyboard.
            let visibleTop = max(top + 4, surface.frame.minY)
            let visibleBottom = min(bottom - 4, surface.frame.maxY)
            let height = max(0, visibleBottom - visibleTop)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = surface.frame.minX + surface.frame.width * 0.02 - app.frame.minX
            let start = origin.withOffset(CGVector(dx: x, dy: visibleTop + height * (down ? 0.25 : 0.75) - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: x, dy: visibleTop + height * (down ? 0.75 : 0.25) - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture("Unreachable audit target")
        XCTFail("Unreachable target: \(element); \(app.debugDescription)")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
