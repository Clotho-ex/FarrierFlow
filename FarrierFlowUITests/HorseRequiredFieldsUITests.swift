import XCTest

final class HorseRequiredFieldsUITests: XCTestCase {
    private let locationName = "Next Appointment Service Location"
    private let clientName = "Next Appointment Client"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testDefaultRowsMeetNativeSpacing() throws {
        let app = openHorse()
        defer { app.terminate() }
        let before = rowFrames(in: app)
        recordHeights(before, name: "Empty form", in: app)
        XCTAssertTrue((76...88).contains(before[0].height), "Name group: \(before[0].height)")
        for row in before[1...2] {
            XCTAssertEqual(row.height, 54, accuracy: 3, "Selection row: \(row.height)")
        }
        XCTAssertEqual(nameInput(in: app).placeholderValue, "Enter horse name")
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, "Select")
        app.buttons["horse-save-action"].tap()
        assertNamePrompt("Horse name required", in: app)
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, "Required")
        XCTAssertEqual(app.buttons["horse-client-picker"].value as? String, clientName)
        assertSameFrames(before, rowFrames(in: app))
        recordHeights(rowFrames(in: app), name: "Both missing fields", in: app)
        XCTAssertFalse(app.staticTexts["horse-required-name"].exists)
        XCTAssertFalse(app.staticTexts["horse-required-serviceLocation"].exists)
        focusName(in: app)
        dismissKeyboard(in: app)
        try auditAccessibility(in: app)

        let more = app.buttons.matching(identifier: "horse-more-details")
            .matching(NSPredicate(format: "label == %@", "More Details")).firstMatch
        more.tap()
        let notes = app.textViews["Additional Notes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 3))
        reveal(more, in: app, towardTop: true)
        more.tap()
        XCTAssertTrue(notes.waitForNonExistence(timeout: 3))
        assertNamePrompt("Horse name required", in: app)
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, "Required")
        app.buttons["horse-save-action"].tap()
        assertNamePrompt("Horse name required", in: app)
        capture("Compact fields after repeated Save and More Details", in: app)
    }

    @MainActor
    func testMissingNameUsesNativePromptAndCorrectsWithKeyboard() {
        let app = openHorse()
        defer { app.terminate() }
        chooseLocation(in: app)
        let name = nameInput(in: app)
        focusName(in: app)
        name.typeText("  ")
        dismissKeyboard(in: app)
        let before = rowFrames(in: app)
        app.buttons["horse-save-action"].tap()
        assertNamePrompt("Horse name required", in: app)
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, locationName)
        assertSameFrames(before, rowFrames(in: app))
        capture("Name-only validation leaves configured fields neutral", in: app)
        focusName(in: app)
        name.typeText("Native Horse")
        XCTAssertEqual(name.value as? String, "Native Horse")
        assertNamePrompt("Enter horse name", in: app)
        capture("Native Horse keyboard and corrected field", in: app)
        dismissKeyboard(in: app)
        app.buttons["horse-save-action"].tap()
        verifySavedHorse("Native Horse", parent: "Client", in: app)
    }

    @MainActor
    func testMissingLocationUsesExistingValueAreaAndKeepsDraft() {
        let app = openHorse()
        defer { app.terminate() }
        focusName(in: app)
        nameInput(in: app).typeText("Location Horse")
        dismissKeyboard(in: app)
        let before = rowFrames(in: app)
        app.buttons["horse-save-action"].tap()
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, "Required")
        XCTAssertEqual(nameInput(in: app).value as? String, "Location Horse")
        assertNamePrompt("Enter horse name", in: app)
        assertSameFrames(before, rowFrames(in: app))
        capture("Location-only validation inside native selector", in: app)
        app.buttons["horse-barn-picker"].tap()
        let selector = app.navigationBars["Select Service Location"]
        XCTAssertTrue(selector.waitForExistence(timeout: 3))
        selector.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, "Required")
        XCTAssertEqual(nameInput(in: app).value as? String, "Location Horse")
        chooseLocation(in: app)
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, locationName)
        app.buttons["horse-save-action"].tap()
        verifySavedHorse("Location Horse", parent: "Client", in: app)
    }

    @MainActor
    func testLargestTextDarkModeKeepsNativeInputAndAccessibleErrors() throws {
        let app = openHorse(largestText: true)
        defer { app.terminate() }
        // A normal input interaction expands the native sheet; validation does not change its detent.
        focusName(in: app, largestText: true)
        dismissKeyboard(in: app)
        app.buttons["horse-save-action"].tap()
        let name = nameInput(in: app)
        assertNamePrompt("Required", in: app)
        XCTAssertEqual(name.label, "Horse Name")
        XCTAssertTrue([XCUIElement.ElementType.textField, .textView].contains(name.elementType))
        let location = app.buttons["horse-barn-picker"]
        XCTAssertEqual(location.label, "Service Location")
        XCTAssertEqual(location.value as? String, "Required")
        XCTAssertEqual(app.buttons["horse-client-picker"].label, "Client")
        capture("Native errors at largest text in dark mode", in: app)
        try auditAccessibility(in: app)
        let description = XCTAttachment(string: app.debugDescription)
        description.name = "Native accessible Horse controls and required values"
        description.lifetime = .keepAlways
        add(description)

        let longName = "North Meadow Morning Star With a Long Registered Name"
        let emptyHeight = name.frame.height
        focusName(in: app, largestText: true)
        name.typeText(longName)
        XCTAssertEqual(name.value as? String, longName)
        XCTAssertGreaterThan(name.frame.height, emptyHeight)
        dismissKeyboard(in: app)
        chooseLocation(in: app)
        XCTAssertEqual(name.value as? String, longName)
        capture("Long name wraps in native input with corrected fields", in: app)
        app.buttons["horse-save-action"].tap()
        verifySavedHorse(longName, parent: "Client", in: app)
    }

    @MainActor
    func testMissingClientUsesNativeSelectionWithoutLosingLocation() {
        let app = openHorse(fromLocation: true)
        defer { app.terminate() }
        focusName(in: app)
        nameInput(in: app).typeText("Barn Horse")
        dismissKeyboard(in: app)
        app.buttons["horse-save-action"].tap()
        let client = app.buttons["horse-client-picker"]
        XCTAssertEqual(client.label, "Client")
        XCTAssertEqual(client.value as? String, "Required")
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, locationName)
        capture("Missing Client inside existing selector", in: app)
        client.tap()
        let choice = app.buttons[clientName]
        XCTAssertTrue(choice.waitForExistence(timeout: 3))
        choice.tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
        XCTAssertEqual(client.value as? String, clientName)
        XCTAssertEqual(nameInput(in: app).value as? String, "Barn Horse")
        XCTAssertEqual(app.buttons["horse-barn-picker"].value as? String, locationName)
        app.buttons["horse-save-action"].tap()
        XCTAssertTrue(app.buttons["horse-row-Barn Horse"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openHorse(largestText: Bool = false, fromLocation: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "NativeHorse-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "next-appointment"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = largestText ? "accessibility5" : "large"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", largestText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        if fromLocation {
            app.openBusinessRoot()
            let locations = app.buttons["Service Locations"]
            reveal(locations, in: app)
            locations.tap()
            let barn = app.buttons["barn-row-\(locationName)"]
            XCTAssertTrue(barn.waitForExistence(timeout: 5))
            barn.tap()
        } else {
            openClient(in: app)
        }
        let add = app.buttons["Add Horse"]
        reveal(add, in: app)
        add.tap()
        XCTAssertTrue(app.buttons["horse-save-action"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func openClient(in app: XCUIApplication) {
        app.selectFarrierFlowTab("Clients")
        let client = app.buttons["client-row-\(clientName)"]
        XCTAssertTrue(client.waitForExistence(timeout: 5))
        client.press(forDuration: 0.1)
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func nameInput(in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["horse-name-field"]
        return field.exists ? field : app.textViews["horse-name-field"]
    }

    @MainActor
    private func assertNamePrompt(_ expected: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let name = nameInput(in: app)
        XCTAssertTrue(name.placeholderValue == expected || name.value as? String == expected
            || name.staticTexts[expected].exists, "Native prompt should be \(expected): \(name.debugDescription)", file: file, line: line)
    }

    @MainActor
    private func focusName(in app: XCUIApplication, largestText: Bool = false) {
        let name = nameInput(in: app)
        reveal(name, in: app, towardTop: true)
        for position in largestText ? [0.5, 0.8] : [0.8, 0.5] {
            name.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: position)).tap()
            let focus = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: name)
            if XCTWaiter.wait(for: [focus], timeout: 2) == .completed { break }
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), app.debugDescription)
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["horse-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["New Horse"].exists)
    }

    @MainActor
    private func chooseLocation(in app: XCUIApplication) {
        let location = app.buttons["horse-barn-picker"]
        reveal(location, in: app)
        location.tap()
        let barn = app.buttons[locationName]
        reveal(barn, in: app)
        barn.tap()
        XCTAssertTrue(app.navigationBars["New Horse"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func rowFrames(in app: XCUIApplication) -> [CGRect] {
        [nameInput(in: app), app.buttons["horse-client-picker"], app.buttons["horse-barn-picker"], app.buttons["horse-more-details"]].map {
            app.cells.containing($0.elementType, identifier: $0.identifier).firstMatch.frame
        }
    }

    private func assertSameFrames(_ before: [CGRect], _ after: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
        for (old, new) in zip(before, after) {
            XCTAssertEqual(old.minY, new.minY, accuracy: 1, file: file, line: line)
            XCTAssertEqual(old.height, new.height, accuracy: 1, file: file, line: line)
        }
    }

    @MainActor
    private func recordHeights(_ frames: [CGRect], name: String, in app: XCUIApplication) {
        let metrics = "\(name): Name \(frames[0].height), Client \(frames[1].height), Location \(frames[2].height), More Details \(frames[3].height), group \(frames.reduce(CGRect.null) { $0.union($1) }.height)"
        print(metrics)
        let attachment = XCTAttachment(string: metrics)
        attachment.name = name + " row heights"
        attachment.lifetime = .keepAlways
        add(attachment)
        capture(name, in: app)
    }

    @MainActor
    private func auditAccessibility(in app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.contrast, .sufficientElementDescription, .textClipped, .trait]) { issue in
            print("Accessibility audit: \(issue.compactDescription); \(issue.detailedDescription); \(issue.element?.debugDescription ?? "No element")")
            return false
        }
    }

    @MainActor
    private func verifySavedHorse(_ name: String, parent: String, in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars[parent].waitForExistence(timeout: 5))
        let horse = app.buttons["horse-row-\(name)"]
        reveal(horse, in: app)
        XCTAssertTrue(horse.exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openClient(in: app)
        reveal(horse, in: app)
        XCTAssertTrue(horse.exists)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<20 {
            let top = app.navigationBars.allElementsBoundByIndex.map { $0.frame.maxY }.max() ?? 80
            let surface = app.collectionViews.allElementsBoundByIndex.last ?? app
            let inHorseSheet = app.navigationBars["New Horse"].exists || app.navigationBars["Edit Horse"].exists
            let bottom = inHorseSheet ? min(surface.frame.maxY, app.frame.maxY) - 16 : app.tabBars.firstMatch.frame.minY
            if element.exists, element.isHittable, element.frame.midY > top, element.frame.midY < bottom { return }
            let above = element.exists ? element.frame.midY <= top : towardTop
            let upper = (top + (bottom - top) * 0.2) / app.frame.height
            let lower = (top + (bottom - top) * 0.8) / app.frame.height
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: above ? upper : lower))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: above ? lower : upper)))
        }
        capture("Horse control reveal diagnostic", in: app)
        XCTFail("Expected visible Horse control: \(element); \(app.debugDescription)")
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
    }
}
