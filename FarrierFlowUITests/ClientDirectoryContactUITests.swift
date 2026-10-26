import XCTest

final class ClientDirectoryContactUITests: XCTestCase {
    private let longName = "Alexandria Montgomery-Wellington and Family"
    private let longEmail = "alexandria.montgomery.wellington.appointments@northfield.example"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testQuickCallAndContactActionsAreIndependentOfNativeNavigation() {
        let app = launch()
        defer { app.terminate() }
        let row = app.buttons["client-row-Jeremy Clarkson"]
        let call = app.buttons["client-call-Jeremy Clarkson"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.label.contains("2 horses"))
        XCTAssertFalse(row.label.contains("555-0124"))
        XCTAssertEqual(call.label, "Call Jeremy Clarkson")
        XCTAssertGreaterThanOrEqual(call.frame.width, 43.99)
        XCTAssertGreaterThanOrEqual(call.frame.height, 43.99)
        capture(app, "Clients — Light")

        // Capture OpenURLAction in the isolated fixture; never contact a real recipient.
        call.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        assertDispatch("tel:+19285550124", count: 1, in: app)
        XCTAssertTrue(app.navigationBars["Clients"].exists)
        XCTAssertFalse(app.navigationBars["Client"].exists)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()
        // Blank space beside the labels belongs to navigation, not quick calling.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        assertDispatch("tel:+19285550124", count: 1, in: app)
        XCTAssertTrue(app.staticTexts["Contact"].exists)
        XCTAssertFalse(app.staticTexts["Profile"].exists)
        XCTAssertEqual(app.staticTexts["client-identity-name"].label, "Jeremy Clarkson")
        let phone = element("client-phone-action", in: app)
        XCTAssertTrue(phone.label.contains("+1 (928) 555-0124"))
        XCTAssertGreaterThanOrEqual(phone.frame.height, 43.99)
        XCTAssertEqual(phone.images.count, 0)
        phone.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        assertDispatch("tel:+19285550124", count: 2, in: app)
        element("client-email-action", in: app).tap()
        assertDispatch("mailto:jeremy@example.com", count: 3, in: app)
        XCTAssertTrue(app.navigationBars["Client"].exists)
        let notes = element("client-notes", in: app)
        XCTAssertTrue(notes.label.contains("Likes beer."))
        XCTAssertTrue(notes.label.contains("Call before arrival"))
        XCTAssertTrue(notes.label.contains("\n\n"))
        let horse = app.buttons["horse-row-Burger"]
        reveal(horse, in: app)
        XCTAssertTrue(horse.label.contains("Diddly Squat Farm"))
        horse.tap()
        XCTAssertTrue(app.navigationBars["Burger"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Client"].tap()
        reveal(app.buttons["Add Horse"], in: app)
        app.buttons["Add Horse"].tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["horse-client-picker"].value as? String, "Jeremy Clarkson")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testClientDetailHierarchyInLightAndDarkMode() {
        for dark in [false, true] {
            let app = launch(dark: dark)
            app.buttons["client-row-Jeremy Clarkson"].tap()
            XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["Contact"].exists)
            XCTAssertEqual(app.staticTexts["client-identity-name"].label, "Jeremy Clarkson")
            XCTAssertTrue(element("client-phone-action", in: app).label.contains("+1 (928) 555-0124"))
            XCTAssertTrue(element("client-email-action", in: app).label.contains("jeremy@example.com"))
            XCTAssertTrue(element("client-notes", in: app).label.contains("Likes beer."))
            capture(app, "Client — \(dark ? "Dark" : "Light"), standard text")
            reveal(app.buttons["horse-row-Burger"], in: app)
            XCTAssertTrue(app.buttons["horse-row-Burger"].label.contains("Diddly Squat Farm"))
            capture(app, "Client — \(dark ? "Dark" : "Light"), notes and horses")
            app.terminate()
        }
    }

    @MainActor
    func testHiddenPhoneAndHorseSearchAndMissingContactStates() {
        let app = launch()
        defer { app.terminate() }
        let jeremy = app.buttons["client-row-Jeremy Clarkson"]
        XCTAssertTrue(jeremy.waitForExistence(timeout: 3))
        let names = [longName, "Jeremy Clarkson", "Morgan Reed", "Nora Wells"]
        let rows = names.map { app.buttons["client-row-\($0)"] }
        XCTAssertEqual(rows.map { $0.frame.minY }, rows.map { $0.frame.minY }.sorted())
        XCTAssertTrue(app.buttons["client-row-Morgan Reed"].label.contains("1 horse"))
        XCTAssertFalse(app.buttons["client-call-Morgan Reed"].exists)
        XCTAssertFalse(app.buttons["client-call-Nora Wells"].exists)
        search("9285550124", in: app)
        XCTAssertTrue(jeremy.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["client-row-Morgan Reed"].exists)
        search("Burger", in: app)
        XCTAssertTrue(jeremy.waitForExistence(timeout: 3))
        search("Nobody here", in: app)
        XCTAssertFalse(jeremy.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "No Results")).firstMatch.exists)
        search("Morgan", in: app)
        app.buttons["client-row-Morgan Reed"].tap()
        XCTAssertTrue(app.buttons["Add Contact Details"].waitForExistence(timeout: 3))
        XCTAssertFalse(element("client-notes", in: app).exists)
        XCTAssertFalse(element("client-phone-action", in: app).exists)
        app.navigationBars.buttons["Clients"].tap()
        search("Nora", in: app)
        app.buttons["client-row-Nora Wells"].tap()
        XCTAssertTrue(app.staticTexts["Ask at the barn"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.links.count, 0)
        XCTAssertFalse(element("ui-test-contact-url", in: app).exists)
    }

    @MainActor
    func testLongContactAndMultilineNotesAtLargestTextInDarkMode() {
        let app = launch(largestText: true)
        defer { app.terminate() }
        let row = app.buttons["client-row-\(longName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.label.contains(longName))
        XCTAssertTrue(row.label.contains("0 horses"))
        let call = app.buttons["client-call-\(longName)"]
        XCTAssertGreaterThanOrEqual(call.frame.width, 43.99)
        XCTAssertGreaterThanOrEqual(call.frame.height, 43.99)
        XCTAssertLessThanOrEqual(call.frame.maxX, app.frame.maxX)
        XCTAssertLessThanOrEqual(row.frame.maxX, call.frame.minX)
        capture(app, "Clients — Dark, largest text")
        row.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["client-identity-name"].label, longName)
        capture(app, "Client — Dark, largest text, identity")
        let phone = element("client-phone-action", in: app)
        reveal(phone, in: app)
        XCTAssertTrue(phone.label.contains("+44 7700 900123"))
        phone.tap()
        assertDispatch("tel:+447700900123", count: 1, in: app)
        let email = element("client-email-action", in: app)
        reveal(email, in: app)
        XCTAssertTrue(email.label.contains(longEmail))
        XCTAssertGreaterThan(email.frame.height, phone.frame.height)
        XCTAssertLessThanOrEqual(email.frame.maxX, app.frame.maxX)
        capture(app, "Client — Dark, largest text, contact")
        email.tap()
        assertDispatch("mailto:\(longEmail)", count: 2, in: app)
        let notes = element("client-notes", in: app)
        reveal(notes, in: app)
        XCTAssertTrue(notes.label.contains("Please call before arrival."))
        XCTAssertTrue(notes.label.contains("Bring the horses into the yard"))
        capture(app, "Client — Dark, largest text, notes")
        reveal(app.buttons["Add Horse"], in: app)
        XCTAssertTrue(app.navigationBars["Client"].exists)
        capture(app, "Client — Dark, largest text, horses")
        app.buttons["Add Horse"].tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        reveal(app.buttons["horse-client-picker"], in: app)
        XCTAssertEqual(app.buttons["horse-client-picker"].value as? String, longName)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testClientContactRemainsUsableWithReadOnlySubscription() {
        let app = launch(readOnly: true)
        defer { app.terminate() }
        app.buttons["client-call-Jeremy Clarkson"].tap()
        assertDispatch("tel:+19285550124", count: 1, in: app)
        app.buttons["client-row-Jeremy Clarkson"].tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        element("client-email-action", in: app).tap()
        assertDispatch("mailto:jeremy@example.com", count: 2, in: app)
        XCTAssertFalse(app.buttons["Add Horse"].exists)
    }

    @MainActor
    private func launch(largestText: Bool = false, readOnly: Bool = false, dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "ClientContacts-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "client-directory"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_CAPTURE_CONTACT_ACTIONS"] = "1"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText || dark ? "dark" : "light"
        if largestText { app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5" }
        if readOnly { app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.selectFarrierFlowTab("Clients")
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func assertDispatch(_ url: String, count: Int, in app: XCUIApplication) {
        let capture = element("ui-test-contact-url", in: app)
        XCTAssertTrue(capture.waitForExistence(timeout: 3))
        XCTAssertEqual(capture.label, url)
        XCTAssertEqual(capture.value as? String, String(count))
    }

    @MainActor
    private func search(_ query: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 2) { app.swipeDown() }
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let previous = field.value as? String ?? ""
        if previous != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(query)
    }

    @MainActor
    private func reveal(_ target: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            let top = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.maxY }.max() ?? 100
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
            if target.exists, target.isHittable, target.frame.midY > top + 4, target.frame.midY < bottom - 4 { return }
            let down = target.exists && target.frame.midY < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let height = bottom - top
            let start = origin.withOffset(CGVector(dx: 5, dy: top + height * (down ? 0.25 : 0.75)))
            let end = origin.withOffset(CGVector(dx: 5, dy: top + height * (down ? 0.75 : 0.25)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Unable to reveal \(target.identifier): \(app.debugDescription)")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
