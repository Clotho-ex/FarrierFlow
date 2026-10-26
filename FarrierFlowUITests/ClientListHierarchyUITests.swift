import XCTest

final class ClientListHierarchyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCountsAndLongNamesPreserveTheListInLightAndDarkMode() {
        let app = launch()
        defer { app.terminate() }
        editSeededClient(name: "Arthur Morgan", in: app)
        let arthur = app.buttons["client-row-Arthur Morgan"]
        XCTAssertTrue(arthur.waitForExistence(timeout: 3))
        capture(app, name: "Clients — Light, standard text")
        print("CLIENT_ROW_FRAME standard=\(arthur.frame)")
        XCTAssertTrue(arthur.label.contains("3 horses"))
        XCTAssertFalse(arthur.label.contains("+13625849"))

        app.navigationBars["Clients"].buttons["Add Client"].tap()
        fillName(longName, in: app)
        app.buttons["client-more-details"].tap()
        fillPhone(in: app)
        app.navigationBars["New Client"].buttons["Save"].tap()
        let longRow = app.buttons["client-row-\(longName)"]
        XCTAssertTrue(longRow.waitForExistence(timeout: 3))
        XCTAssertTrue(longRow.label.contains("0 horses"))
        capture(app, name: "Clients — Light, long name")

        app.terminate()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        app.launch()
        app.selectFarrierFlowTab("Clients")
        XCTAssertTrue(arthur.waitForExistence(timeout: 3))
        XCTAssertTrue(arthur.label.contains("3 horses"))
        XCTAssertTrue(longRow.label.contains("0 horses"))
        capture(app, name: "Clients — Dark, standard text")
        arthur.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLongNameAndCountRemainReadableAtLargestAccessibilitySize() {
        let app = launch(accessibility: true)
        defer { app.terminate() }
        editSeededClient(name: longName, in: app)
        let row = app.buttons["client-row-\(longName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.label.contains(longName))
        XCTAssertFalse(row.label.contains("+13625849"))
        XCTAssertTrue(row.label.contains("3 horses"))
        capture(app, name: "Clients — Dark, largest accessibility text")
        row.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testClientProfileHasNeutralNativeContactActions() {
        let app = launch()
        defer {
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }
        editSeededClient(name: "John Doe", email: "example@gmail.com", in: app)
        app.buttons["client-row-John Doe"].tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        capture(app, name: "Client profile — Light")
        XCTAssertTrue(app.staticTexts["Contact"].exists)
        XCTAssertFalse(app.staticTexts["Client profile"].exists)
        assertContactActions(in: app, email: "example@gmail.com")
        XCTAssertTrue(app.buttons["Add Horse"].isHittable)
        app.buttons["Add Horse"].tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        app.terminate()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        app.launch()
        app.selectFarrierFlowTab("Clients")
        app.buttons["client-row-John Doe"].tap()
        assertContactActions(in: app, email: "example@gmail.com")
        capture(app, name: "Client profile — Dark")
        XCUIDevice.shared.orientation = .landscapeLeft
        app.collectionViews.firstMatch.swipeDown(velocity: .slow)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        capture(app, name: "Client profile — Landscape", fullScreen: true)
    }

    @MainActor
    func testClientProfileLongEmailRemainsReadableAtAccessibilitySize() {
        let address = "alexandria.montgomery.wellington+appointments@northfield.example.com"
        let app = launch()
        defer { app.terminate() }
        editSeededClient(name: longName, email: address, in: app)
        app.buttons["client-row-\(longName)"].tap()
        assertContactActions(in: app, email: address)
        capture(app, name: "Client profile — Long email, standard text")
        app.terminate()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        app.launch()
        app.selectFarrierFlowTab("Clients")
        app.buttons["client-row-\(longName)"].tap()
        XCTAssertTrue(app.staticTexts["Contact"].waitForExistence(timeout: 3))
        capture(app, name: "Client profile — Largest accessibility text, top")
        assertContactActions(in: app, email: address)
        let email = contactAction("client-email-action", in: app)
        app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        XCTAssertTrue(email.exists)
        capture(app, name: "Client profile — Largest accessibility text, email")
        let addHorse = app.buttons["Add Horse"]
        for _ in 0..<8 where !addHorse.isHittable {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(addHorse.isHittable)
        capture(app, name: "Client profile — Largest accessibility text, horses")
        addHorse.tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testClientPhoneLinksAreDiscoverableInProfileAndAppointment() {
        for largestText in [false, true] {
            let app = XCUIApplication()
            app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "PhoneAffordances-\(UUID())"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
            if largestText {
                app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            }
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            app.selectFarrierFlowTab("Clients")
            app.buttons["client-row-Invoice Client"].tap()
            verifyPhone("client-phone-action", largestText: largestText, in: app)
            capture(app, name: "Client profile call affordance AX \(largestText)")
            app.selectFarrierFlowTab("Schedule")
            app.segmentedControls["schedule-status-tabs"].buttons["Completed"].tap()
            let appointment = app.buttons["appointment-row-Invoice Service Location"].firstMatch
            XCTAssertTrue(appointment.waitForExistence(timeout: 3))
            appointment.tap()
            verifyPhone("appointment-call-Milo", largestText: largestText, in: app)
            capture(app, name: "Appointment call affordance AX \(largestText)")
            app.terminate()
        }
    }

    @MainActor
    private func verifyPhone(_ identifier: String, largestText: Bool, in app: XCUIApplication) {
        let phone = contactAction(identifier, in: app)
        for _ in 0..<10 {
            let top = app.navigationBars.allElementsBoundByIndex.map { $0.frame.maxY }.max() ?? 100
            if phone.exists, phone.isHittable,
               phone.frame.minY >= top, phone.frame.maxY <= app.tabBars.firstMatch.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(phone.exists)
        XCTAssertTrue(phone.isHittable)
        XCTAssertTrue(phone.isEnabled)
        XCTAssertTrue(phone.label.contains("Call 555-0100"))
        XCTAssertTrue(phone.elementType == .link || phone.elementType == .button)
        XCTAssertGreaterThanOrEqual(phone.frame.height, 44)
        if !largestText {
            XCTAssertLessThan(phone.frame.height, 100, "A short phone number must retain a compact row.")
        }
    }

    @MainActor
    private func assertContactActions(in app: XCUIApplication, email address: String) {
        let phone = contactAction("client-phone-action", in: app)
        let email = contactAction("client-email-action", in: app)
        XCTAssertTrue(phone.waitForExistence(timeout: 3))
        XCTAssertTrue(phone.label.contains("+13625849"))
        XCTAssertTrue(phone.elementType == .link || phone.elementType == .button)
        for _ in 0..<8 where !email.exists {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(email.exists)
        XCTAssertTrue(email.label.contains(address))
        XCTAssertTrue(email.elementType == .link || email.elementType == .button)
    }

    @MainActor
    private func contactAction(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private var longName: String {
        "Alexandria Montgomery-Wellington and Family"
    }

    @MainActor
    private func launch(accessibility: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "ClientHierarchy-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "next-appointment"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = accessibility ? "dark" : "light"
        if accessibility {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        app.selectFarrierFlowTab("Clients")
        return app
    }

    @MainActor
    private func editSeededClient(name: String, email: String? = nil, in app: XCUIApplication) {
        let row = app.buttons["client-row-Next Appointment Client"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        app.navigationBars["Client"].buttons["Actions"].tap()
        app.buttons["Edit"].tap()
        fillName(name, in: app)
        fillPhone(in: app)
        if let email {
            replaceText(email, in: app.textFields["client-email-field"], app: app)
            dismissKeyboard(in: app)
        }
        app.navigationBars["Edit Client"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Edit Client"].waitForNonExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()
    }

    @MainActor
    private func fillName(_ name: String, in app: XCUIApplication) {
        replaceText(name, in: app.textFields["client-name-field"], app: app)
        dismissKeyboard(in: app)
    }

    @MainActor
    private func fillPhone(in app: XCUIApplication) {
        replaceText("+13625849", in: app.textFields["client-phone-field"], app: app)
        dismissKeyboard(in: app)
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["client-keyboard-done"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    @MainActor
    private func replaceText(_ text: String, in field: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let original = (field.value as? String) ?? ""
        for attempt in 0..<3 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: attempt == 0 ? 0.5 : 0.85)).tap()
            let focus = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field
            )
            if XCTWaiter.wait(for: [focus], timeout: 2) == .completed {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count))
                field.typeText(text)
                return
            }
        }
        XCTFail("Expected input field to receive keyboard focus")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String, fullScreen: Bool = false) {
        let attachment = XCTAttachment(screenshot: fullScreen ? XCUIScreen.main.screenshot() : app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
