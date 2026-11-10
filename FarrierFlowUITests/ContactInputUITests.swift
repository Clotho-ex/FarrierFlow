import XCTest

final class ContactInputUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testClientFormattingValidationAndLimitsPersist() {
        verifyClient(largestText: false)
    }

    @MainActor
    func testClientInputsAtLargestTextInDarkMode() {
        verifyClient(largestText: true)
    }

    @MainActor
    func testBusinessEmailValidationAndPhoneFormatting() {
        let app = launch()
        defer { app.terminate() }
        app.openBusinessRoot()
        let business = app.buttons["Business Profile"]
        reveal(business, in: app)
        business.tap()
        let name = app.textFields["business-profile-name-field"]
        replace("Field Farrier", in: name, app: app)
        let phone = app.textFields["business-profile-phone-field"]
        replace("2025550143", in: phone, app: app)
        let email = app.textFields["business-profile-email-field"]
        replace("alex@@example.com", in: email, app: app)
        XCTAssertEqual(phone.value as? String, "+1 202-555-0143")
        app.buttons["Done"].tap()
        let error = element("business-profile-email-error", in: app)
        reveal(error, in: app, requiresHitTarget: false)
        XCTAssertTrue(error.exists)
        XCTAssertFalse(app.buttons["business-profile-save-action"].isEnabled)
        capture(app, "Business email validation")
        replace("alex+business@example.com", in: email, app: app)
        app.buttons["Done"].tap()
        XCTAssertFalse(error.exists)
        XCTAssertTrue(app.buttons["business-profile-save-action"].isEnabled)
        app.buttons["business-profile-save-action"].tap()
        XCTAssertTrue(business.waitForExistence(timeout: 5))
        reveal(business, in: app)
        business.tap()
        reveal(phone, in: app)
        XCTAssertEqual(phone.value as? String, "+1 202-555-0143")
    }

    @MainActor
    private func verifyClient(largestText: Bool) {
        let app = launch(largestText: largestText)
        defer { app.terminate() }
        app.selectFarrierFlowTab("Clients")
        let addClient = app.navigationBars["Clients"].buttons["Add Client"]
        XCTAssertTrue(addClient.waitForExistence(timeout: 5))
        addClient.tap()
        let name = app.textFields["client-name-field"]
        if !name.waitForExistence(timeout: 5) {
            addClient.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1)
        }
        guard name.waitForExistence(timeout: 5) else {
            capture(app, "New Client did not open")
            XCTFail("Expected the New Client form after the toolbar action")
            return
        }
        replace(String(repeating: "A", count: 61), in: name, app: app)
        let savedName = String(repeating: "A", count: 60)
        XCTAssertEqual(name.value as? String, savedName)
        let more = app.buttons["client-more-details"]
        reveal(more, in: app)
        more.tap()
        let phone = app.textFields["client-phone-field"]
        replace(String(repeating: "2", count: 25), in: phone, app: app)
        XCTAssertEqual((phone.value as? String)?.count, 25)
        phone.typeText("2")
        XCTAssertEqual((phone.value as? String)?.count, 25)
        replace("2025550143", in: phone, app: app)
        let email = app.textFields["client-email-field"]
        replace("alex@@example.com", in: email, app: app)
        XCTAssertEqual(phone.value as? String, "+1 202-555-0143")
        XCTAssertEqual(email.value as? String, "alex@@example.com")
        app.buttons["client-keyboard-done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        let error = element("client-email-error", in: app)
        reveal(error, in: app, requiresHitTarget: false)
        XCTAssertTrue(error.exists)
        XCTAssertFalse(app.navigationBars["New Client"].buttons["Save"].isEnabled)
        capture(app, "Client invalid email \(largestText ? "largest dark" : "standard")")
        let longEmail = String(repeating: "a", count: 64) + "@" + String(repeating: "b", count: 32) + ".com"
        replace(longEmail, in: email, app: app)
        XCTAssertLessThanOrEqual((email.value as? String)?.count ?? 101, 100)
        replace("alex+visits@example.com", in: email, app: app)
        XCTAssertEqual(email.value as? String, "alex+visits@example.com")
        reveal(element("client-notes-field", in: app), in: app)
        let noteTextView = app.textViews["client-notes-field"]
        let notes = noteTextView.exists ? noteTextView : app.textFields["client-notes-field"]
        replace(String(repeating: "n", count: 501), in: notes, app: app)
        XCTAssertEqual((notes.value as? String)?.count, 500)
        app.buttons["client-keyboard-done"].tap()
        XCTAssertFalse(error.exists)
        XCTAssertTrue(app.navigationBars["New Client"].buttons["Save"].isEnabled)
        capture(app, "Client notes limit \(largestText ? "largest dark" : "standard")")
        app.navigationBars["New Client"].buttons["Save"].tap()
        let row = app.buttons["client-row-\(savedName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let call = app.buttons["client-call-\(savedName)"]
        reveal(call, in: app)
        call.tap()
        XCTAssertEqual(element("ui-test-contact-url", in: app).label, "tel:+12025550143")
        app.buttons["client-email-\(savedName)"].tap()
        XCTAssertEqual(element("ui-test-contact-url", in: app).label, "mailto:alex+visits@example.com")
        app.terminate()
        app.launch()
        app.selectFarrierFlowTab("Clients")
        reveal(row, in: app)
        row.tap()
        let information = element("client-phone-information", in: app)
        reveal(information, in: app, requiresHitTarget: false)
        XCTAssertTrue(information.label.contains("+1 202-555-0143"))
        let savedNotes = element("client-notes", in: app)
        reveal(savedNotes, in: app, requiresHitTarget: false)
        XCTAssertTrue(savedNotes.label.contains(String(repeating: "n", count: 500)))
    }

    @MainActor
    private func launch(largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "ContactInputs-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "client-directory"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_CAPTURE_CONTACT_ACTIONS"] = "1"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func replace(_ value: String, in field: XCUIElement, app: XCUIApplication) {
        reveal(field, in: app)
        let focusPredicate = NSPredicate(format: "hasKeyboardFocus == true")
        var hasFocus = focusPredicate.evaluate(with: field)
        if !hasFocus {
            for point in [CGVector(dx: 0.5, dy: 0.5), CGVector(dx: 0.85, dy: 0.5)] {
                field.coordinate(withNormalizedOffset: point).tap()
                let focus = XCTNSPredicateExpectation(predicate: focusPredicate, object: field)
                if XCTWaiter.wait(for: [focus], timeout: 2) == .completed { hasFocus = true; break }
            }
        }
        guard hasFocus else { capture(app, "Input focus failure"); XCTFail("Expected keyboard focus for \(field.identifier)"); return }
        for _ in 0..<8 {
            let previous = field.value as? String ?? ""
            if previous.isEmpty || previous == field.placeholderValue { break }
            reveal(field, in: app)
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).press(forDuration: 1)
            let selectAllItem = app.menuItems["Select All"].firstMatch
            let selectAllButton = app.buttons["Select All"].firstMatch
            if selectAllItem.waitForExistence(timeout: 1) {
                selectAllItem.tap()
                field.typeText(XCUIKeyboardKey.delete.rawValue)
            } else if selectAllButton.exists {
                selectAllButton.tap()
                field.typeText(XCUIKeyboardKey.delete.rawValue)
            } else {
                // The phone-pad edit menu may omit Select All. Move to the visible
                // text end and delete, repeating if a long value was scrolled.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.8)).tap()
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
            }
        }
        let cleared = field.value as? String ?? ""
        guard cleared.isEmpty || cleared == field.placeholderValue else {
            capture(app, "Input clear failure")
            XCTFail("Expected empty input before replacement: \(field.identifier)")
            return
        }
        field.typeText(value)
    }

    @MainActor
    private func reveal(_ target: XCUIElement, in app: XCUIApplication, requiresHitTarget: Bool = true) {
        for _ in 0..<20 {
            let top = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.maxY }.max() ?? 100
            var bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
            if app.keyboards.firstMatch.exists {
                bottom = app.keyboards.firstMatch.frame.minY
                for done in [app.buttons["client-keyboard-done"], app.buttons["Done"].firstMatch] where done.exists && done.isHittable {
                    bottom = min(bottom, done.frame.minY - 4)
                }
            }
            if target.exists, (!requiresHitTarget || target.isHittable), target.frame.midY > top + 4, target.frame.midY < bottom - 4 { return }
            let surface = app.collectionViews.allElementsBoundByIndex.last ?? app
            let startY = max(top + 8, surface.frame.minY) + (min(bottom - 8, surface.frame.maxY) - max(top + 8, surface.frame.minY)) * 0.75
            let endY = max(top + 8, surface.frame.minY) + (min(bottom - 8, surface.frame.maxY) - max(top + 8, surface.frame.minY)) * 0.25
            let down = target.exists && target.frame.midY < top
            let x = surface.frame.minX + 8
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: x, dy: down ? endY : startY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: down ? startY : endY)))
        }
        capture(app, "Unreachable input")
        XCTFail("Unreachable input: \(target.identifier); \(app.debugDescription)")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
