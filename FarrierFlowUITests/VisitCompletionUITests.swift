import XCTest

final class VisitCompletionUITests: XCTestCase {
    @MainActor
    func testVisitProgressCompletionAndHorseHistoryPersistAcrossRelaunches() throws {
        let graph = makeGraph(prefix: "Complete")
        let app = launch(storeName: "VisitCompletion-\(UUID().uuidString)")
        let defaultServiceName = "Complete Trim"
        createService(defaultServiceName, price: "50.00", in: app)
        createConnectedGraph(graph, in: app, defaultServiceName: defaultServiceName)

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-start-action"].tap()
        assertOutcome(.pending, for: graph.servicedHorseName, in: app)
        assertOutcome(.pending, for: graph.notServicedHorseName, in: app)
        XCTAssertFalse(app.buttons["visit-complete"].isEnabled)

        app.buttons["Cancel"].tap()
        attemptRelocation(
            of: graph.servicedHorseName,
            for: graph.clientName,
            to: graph.secondaryBarnName,
            in: app
        )
        XCTAssertTrue(
            app.alerts["Can’t Change Service Location"].waitForExistence(timeout: 3)
        )
        app.alerts.buttons["OK"].tap()
        app.buttons["Cancel"].tap()

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-resume-action"].tap()
        select(.serviced, for: graph.servicedHorseName, in: app)
        let workNotes = app.textViews["visit-work-notes-\(graph.servicedHorseName)"]
        focusAndType("Front shoes", in: workNotes)
        select(.notServiced, for: graph.notServicedHorseName, in: app)
        XCTAssertTrue(app.buttons["visit-save-progress"].isEnabled)
        app.buttons["visit-save-progress"].tap()

        app.terminate()
        app.launch()

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-resume-action"].tap()
        assertOutcome(.serviced, for: graph.servicedHorseName, in: app)
        assertOutcome(.notServiced, for: graph.notServicedHorseName, in: app)
        assertWorkNotes("Front shoes", for: graph.servicedHorseName, in: app)

        app.buttons["visit-complete"].tap()
        XCTAssertTrue(app.buttons["visit-view-action"].waitForExistence(timeout: 3))
        app.buttons["visit-view-action"].tap()
        assertCompletedVisitDetail(graph, in: app)
        app.buttons["visit-detail-done"].tap()

        attemptRelocation(
            of: graph.servicedHorseName,
            for: graph.clientName,
            to: graph.secondaryBarnName,
            in: app
        )
        let location = app.descendants(matching: .any)["horse-detail-service-location"]
        XCTAssertTrue(location.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: location).contains(graph.secondaryBarnName))

        openHorseDetail(graph.servicedHorseName, for: graph.clientName, in: app)
        openHistoryVisit(for: graph.servicedHorseName, in: app)
        assertCompletedVisitDetail(graph, in: app)

        app.terminate()
        app.launch()

        openHorseDetail(graph.servicedHorseName, for: graph.clientName, in: app)
        openHistoryVisit(for: graph.servicedHorseName, in: app)
        assertCompletedVisitDetail(graph, in: app)
    }

    @MainActor
    func testVisitEditorManagesWorkItemsAndConfirmsClearingRecordedWork() throws {
        let graph = makeGraph(prefix: "Work Items")
        let trimServiceName = "Work Items Trim"
        let shoeServiceName = "Work Items Shoes"
        let padServiceName = "Work Items Pads"
        let app = launch(storeName: "VisitWorkItems-\(UUID().uuidString)")
        createService(trimServiceName, price: "50.00", in: app)
        createService(shoeServiceName, price: "125.00", in: app)
        createService(padServiceName, price: "75.00", in: app)
        createConnectedGraph(graph, in: app, defaultServiceName: trimServiceName)

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-start-action"].tap()

        let trimRow = app.buttons[
            "visit-work-item-\(graph.servicedHorseName)-\(trimServiceName)"
        ]
        XCTAssertTrue(trimRow.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: trimRow).contains("$50.00"))

        trimRow.tap()
        let priceField = app.textFields["work-item-price-field"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 3))
        replaceText(with: "0", in: priceField)
        app.buttons["Save"].tap()
        XCTAssertTrue(accessibilityText(of: trimRow).contains("Complimentary"))

        app.buttons["visit-add-service-\(graph.servicedHorseName)"].tap()
        XCTAssertTrue(app.navigationBars["Add Service"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["visit-service-option-\(trimServiceName)"].exists)
        let shoeOption = app.buttons["visit-service-option-\(shoeServiceName)"]
        XCTAssertTrue(shoeOption.waitForExistence(timeout: 3))
        shoeOption.tap()

        XCTAssertTrue(
            app.buttons["visit-work-item-\(graph.servicedHorseName)-\(shoeServiceName)"]
                .waitForExistence(timeout: 3)
        )

        trimRow.tap()
        app.buttons["visit-replace-service"].tap()
        XCTAssertTrue(app.navigationBars["Replace Service"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["visit-service-option-\(trimServiceName)"].exists)
        XCTAssertFalse(app.buttons["visit-service-option-\(shoeServiceName)"].exists)
        app.buttons["visit-service-option-\(padServiceName)"].tap()
        let padRow = app.buttons[
            "visit-work-item-\(graph.servicedHorseName)-\(padServiceName)"
        ]
        XCTAssertTrue(padRow.waitForExistence(timeout: 3))

        let shoeRow = app.buttons[
            "visit-work-item-\(graph.servicedHorseName)-\(shoeServiceName)"
        ]
        shoeRow.tap()
        app.buttons["visit-remove-service"].tap()
        XCTAssertTrue(app.staticTexts["Remove Service?"].waitForExistence(timeout: 3))
        app.buttons["Remove Service"].firstMatch.tap()
        XCTAssertFalse(shoeRow.exists)

        select(.notServiced, for: graph.servicedHorseName, in: app)
        XCTAssertTrue(app.staticTexts["Clear Recorded Work?"].waitForExistence(timeout: 3))
        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(padRow.exists)

        select(.notServiced, for: graph.servicedHorseName, in: app)
        app.buttons["Clear Recorded Work"].tap()
        XCTAssertFalse(padRow.exists)
        XCTAssertFalse(app.buttons["visit-add-service-\(graph.servicedHorseName)"].exists)
    }

    @MainActor
    func testVisitEditorCreatesFirstServiceAndAddsSoleServiceDirectly() throws {
        let graph = makeGraph(prefix: "Candidate Aware")
        let serviceName = "Candidate Aware Trim"
        let app = launch(storeName: "VisitCandidateAware-\(UUID().uuidString)")
        createConnectedGraph(
            graph,
            in: app,
            includesSecondaryBarn: false
        )

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-start-action"].tap()

        app.buttons["visit-add-service-\(graph.servicedHorseName)"].tap()
        XCTAssertTrue(app.navigationBars["Add Service"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Services Available"].exists)
        let createService = app.buttons["visit-create-service-action"]
        XCTAssertTrue(createService.waitForExistence(timeout: 3))

        createService.tap()
        XCTAssertTrue(app.navigationBars["New Service"].waitForExistence(timeout: 3))
        app.navigationBars["New Service"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Add Service"].waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.buttons["visit-work-item-\(graph.servicedHorseName)-\(serviceName)"].exists
        )

        createService.tap()
        focusAndType(serviceName, in: app.textFields["service-name-field"])
        focusAndType("64.50", in: app.textFields["service-price-field"])
        app.buttons["Save"].tap()

        let firstWorkItem = app.buttons[
            "visit-work-item-\(graph.servicedHorseName)-\(serviceName)"
        ]
        XCTAssertTrue(firstWorkItem.waitForExistence(timeout: 3))
        XCTAssertEqual(accessibilityText(of: firstWorkItem).filter(\.isNumber), "6450")

        app.buttons["visit-add-service-\(graph.notServicedHorseName)"].tap()
        let secondWorkItem = app.buttons[
            "visit-work-item-\(graph.notServicedHorseName)-\(serviceName)"
        ]
        XCTAssertTrue(secondWorkItem.waitForExistence(timeout: 3))
        XCTAssertEqual(accessibilityText(of: secondWorkItem).filter(\.isNumber), "6450")
        XCTAssertFalse(app.navigationBars["Add Service"].exists)

        app.buttons["visit-save-progress"].tap()
        app.terminate()
        app.launch()

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-resume-action"].tap()
        XCTAssertTrue(firstWorkItem.waitForExistence(timeout: 3))
        XCTAssertTrue(secondWorkItem.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPendingAndAllNotServicedOutcomesBlockCompletionAndDirtyCancelKeepsEditor() throws {
        let graph = makeGraph(prefix: "Draft")
        let app = launch(
            storeName: "VisitDraftRules-\(UUID().uuidString)",
            forcesCameraUnavailable: true
        )
        createConnectedGraph(graph, in: app, includesSecondaryBarn: false)

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-start-action"].tap()
        let complete = app.buttons["visit-complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 3))
        XCTAssertFalse(complete.isEnabled)

        app.buttons["visit-photographs-\(graph.servicedHorseName)"].tap()
        XCTAssertTrue(app.navigationBars["Hoof Photographs"].waitForExistence(timeout: 3))
        app.buttons["photograph-add-menu"].tap()
        app.buttons["Camera"].tap()
        XCTAssertTrue(app.alerts["Camera Unavailable"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()

        app.buttons["photograph-add-menu"].tap()
        app.buttons["Photo Library"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 5))
        app.navigationBars["Photos"].buttons["Cancel"].tap()
        app.navigationBars.buttons["Visit"].tap()

        select(.notServiced, for: graph.servicedHorseName, in: app)
        select(.notServiced, for: graph.notServicedHorseName, in: app)
        XCTAssertFalse(complete.isEnabled)

        select(.serviced, for: graph.servicedHorseName, in: app)
        XCTAssertTrue(app.staticTexts["visit-unsaved-state"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Discard Unsaved Changes?"].waitForExistence(timeout: 3))
        keepEditing(in: app)
        XCTAssertTrue(
            app.buttons["visit-outcome-\(graph.servicedHorseName)"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["visit-unsaved-state"].exists)
    }

    @MainActor
    func testInProgressDiscardPreservesAppointmentAndBlocksAppointmentDeletion() throws {
        let graph = makeGraph(prefix: "Discard")
        let app = launch(storeName: "VisitDiscard-\(UUID().uuidString)")
        createConnectedGraph(graph, in: app, includesSecondaryBarn: false)

        openAppointment(at: graph.primaryBarnName, in: app)
        app.buttons["visit-start-action"].tap()
        app.buttons["Cancel"].tap()

        app.buttons["appointment-delete-action"].tap()
        app.buttons["appointment-delete-confirmation"].firstMatch.tap()
        XCTAssertTrue(app.alerts["Can’t Delete Appointment"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()

        app.buttons["visit-resume-action"].tap()
        app.buttons["visit-actions-menu"].tap()
        app.buttons["Discard Visit"].tap()
        XCTAssertTrue(app.staticTexts["Discard Visit?"].waitForExistence(timeout: 3))
        app.buttons["Discard Visit"].tap()

        XCTAssertTrue(app.buttons["visit-start-action"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["appointment-row-\(graph.primaryBarnName)"].exists)
    }

    @MainActor
    private func launch(
        storeName: String,
        forcesCameraUnavailable: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        if forcesCameraUnavailable {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_CAMERA_UNAVAILABLE"] = "1"
        }
        app.launch()
        return app
    }

    @MainActor
    private func keepEditing(in app: XCUIApplication) {
        let keepEditing = app.buttons["Keep Editing"]
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 3))
        keepEditing.tap()
    }

    @MainActor
    private func makeGraph(prefix: String) -> ConnectedGraph {
        ConnectedGraph(
            clientName: "\(prefix) Client",
            primaryBarnName: "\(prefix) Barn",
            secondaryBarnName: "\(prefix) Relocation",
            servicedHorseName: "\(prefix) Serviced",
            notServicedHorseName: "\(prefix) Not Serviced"
        )
    }

    @MainActor
    private func createConnectedGraph(
        _ graph: ConnectedGraph,
        in app: XCUIApplication,
        includesSecondaryBarn: Bool = true,
        defaultServiceName: String? = nil
    ) {
        createClient(graph.clientName, in: app)
        createBarn(graph.primaryBarnName, in: app)
        if includesSecondaryBarn {
            createBarn(graph.secondaryBarnName, in: app)
        }
        app.navigationBars.buttons["Clients"].tap()
        app.staticTexts["client-row-\(graph.clientName)"].tap()
        createHorse(
            graph.servicedHorseName,
            barnName: graph.primaryBarnName,
            defaultServiceName: defaultServiceName,
            in: app
        )
        createHorse(graph.notServicedHorseName, barnName: graph.primaryBarnName, in: app)
        scheduleAppointment(
            horseNames: [graph.servicedHorseName, graph.notServicedHorseName],
            barnName: graph.primaryBarnName,
            in: app
        )
    }

    @MainActor
    private func createClient(_ name: String, in app: XCUIApplication) {
        app.tabBars.buttons["Clients"].tap()
        let addClient = app.buttons["Add Client"].firstMatch
        XCTAssertTrue(addClient.waitForExistence(timeout: 5))
        addClient.tap()
        focusAndType(name, in: app.textFields["client-name-field"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["client-row-\(name)"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func createBarn(_ name: String, in app: XCUIApplication) {
        if !app.navigationBars["Service Locations"].exists {
            app.buttons["More"].tap()
            let serviceLocations = app.buttons["Service Locations"].firstMatch
            XCTAssertTrue(serviceLocations.waitForExistence(timeout: 3))
            serviceLocations.tap()
        }
        let addServiceLocation = app.buttons["Add Service Location"].firstMatch
        XCTAssertTrue(addServiceLocation.waitForExistence(timeout: 3))
        addServiceLocation.tap()
        focusAndType(name, in: app.textFields["barn-name-field"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["barn-row-\(name)"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func createHorse(
        _ name: String,
        barnName: String,
        defaultServiceName: String? = nil,
        in app: XCUIApplication
    ) {
        let addHorse = app.buttons["Add Horse"].firstMatch
        XCTAssertTrue(addHorse.waitForExistence(timeout: 3))
        addHorse.tap()
        focusAndType(name, in: app.textFields["horse-name-field"])
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        if let defaultServiceName {
            app.buttons["horse-default-service-picker"].tap()
            let services = app.buttons.matching(identifier: defaultServiceName)
            XCTAssertGreaterThan(services.count, 0)
            guard services.count > 0 else { return }
            let service = services.element(boundBy: services.count - 1)
            XCTAssertTrue(service.waitForExistence(timeout: 3))
            service.tap()
        }
        app.navigationBars["New Horse"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["horse-row-\(name)"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func createService(_ name: String, price: String, in app: XCUIApplication) {
        app.tabBars.buttons["Clients"].tap()
        app.buttons["More"].tap()
        let services = app.buttons["Services"].firstMatch
        XCTAssertTrue(services.waitForExistence(timeout: 3))
        services.tap()
        app.buttons["service-add-action"].tap()
        focusAndType(name, in: app.textFields["service-name-field"])
        focusAndType(price, in: app.textFields["service-price-field"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["service-row-\(name)"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Clients"].tap()
    }

    @MainActor
    private func scheduleAppointment(
        horseNames: [String],
        barnName: String,
        in app: XCUIApplication
    ) {
        app.tabBars.buttons["Today"].tap()
        let addAppointment = app.buttons["Schedule Appointment"].firstMatch
        XCTAssertTrue(addAppointment.waitForExistence(timeout: 3))
        addAppointment.tap()
        app.buttons["appointment-barn-picker"].tap()
        let barnOptions = app.buttons.matching(identifier: barnName)
        XCTAssertTrue(barnOptions.firstMatch.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(barnOptions.count, 0)
        guard barnOptions.count > 0 else { return }
        barnOptions.element(boundBy: barnOptions.count - 1).tap()
        for horseName in horseNames {
            let horseButton = app.buttons["appointment-horse-\(horseName)"].firstMatch
            XCTAssertTrue(horseButton.waitForExistence(timeout: 5))
            horseButton.tap()
        }
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["appointment-row-\(barnName)"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openAppointment(at barnName: String, in app: XCUIApplication) {
        if isPresentingAppointmentDetail(in: app) {
            return
        }
        app.tabBars.buttons["Today"].tap()
        if isPresentingAppointmentDetail(in: app) {
            return
        }
        let appointment = app.staticTexts["appointment-row-\(barnName)"]
        XCTAssertTrue(appointment.waitForExistence(timeout: 3))
        appointment.tap()
    }

    @MainActor
    private func openHorseDetail(_ horseName: String, for clientName: String, in app: XCUIApplication) {
        if app.descendants(matching: .any)["horse-detail-service-location"].exists {
            return
        }
        app.tabBars.buttons["Clients"].tap()
        if app.descendants(matching: .any)["horse-detail-service-location"].exists {
            return
        }
        let existingHorse = app.staticTexts["horse-row-\(horseName)"]
        if existingHorse.exists {
            existingHorse.tap()
            return
        }
        let client = app.staticTexts["client-row-\(clientName)"]
        XCTAssertTrue(client.waitForExistence(timeout: 3))
        client.tap()
        let horse = app.staticTexts["horse-row-\(horseName)"]
        XCTAssertTrue(horse.waitForExistence(timeout: 3))
        horse.tap()
    }

    @MainActor
    private func attemptRelocation(
        of horseName: String,
        for clientName: String,
        to barnName: String,
        in app: XCUIApplication
    ) {
        openHorseDetail(horseName, for: clientName, in: app)
        app.buttons["Edit"].tap()
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["Save"].tap()
    }

    @MainActor
    private func select(_ outcome: VisitOutcome, for horseName: String, in app: XCUIApplication) {
        let picker = app.buttons["visit-outcome-\(horseName)"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        picker.tap()
        let option = app.buttons[outcome.title].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        assertOutcome(outcome, for: horseName, in: app)
    }

    @MainActor
    private func assertOutcome(_ outcome: VisitOutcome, for horseName: String, in app: XCUIApplication) {
        let picker = app.buttons["visit-outcome-\(horseName)"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        XCTAssertTrue(picker.label.contains(horseName))
        XCTAssertTrue(accessibilityText(of: picker).contains(outcome.title))
    }

    @MainActor
    private func assertWorkNotes(_ expected: String, for horseName: String, in app: XCUIApplication) {
        let workNotes = app.textViews["visit-work-notes-\(horseName)"]
        XCTAssertTrue(workNotes.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: workNotes).contains(expected))
    }

    @MainActor
    private func openHistoryVisit(for horseName: String, in app: XCUIApplication) {
        let history = app.descendants(matching: .any)["horse-history-visit-\(horseName)"]
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()
    }

    @MainActor
    private func assertCompletedVisitDetail(_ graph: ConnectedGraph, in app: XCUIApplication) {
        let status = app.staticTexts["visit-detail-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: status).contains("Completed"))
        let snapshot = app.descendants(matching: .any)["visit-detail-service-location-snapshot"].firstMatch
        XCTAssertTrue(snapshot.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: snapshot).contains(graph.primaryBarnName))
        let servicedResult = assertVisitResult(
            .serviced,
            horseName: graph.servicedHorseName,
            in: app
        )
        XCTAssertTrue(accessibilityText(of: servicedResult).contains("Work Notes"))
        XCTAssertTrue(accessibilityText(of: servicedResult).contains("Front shoes"))
        _ = assertVisitResult(.notServiced, horseName: graph.notServicedHorseName, in: app)
    }

    @MainActor
    private func assertVisitResult(
        _ outcome: VisitOutcome,
        horseName: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let result = app.descendants(matching: .any)["visit-result-\(horseName)"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: result).contains(horseName))
        XCTAssertTrue(accessibilityText(of: result).contains(outcome.title))
        return result
    }

    @MainActor
    private func isPresentingAppointmentDetail(in app: XCUIApplication) -> Bool {
        app.buttons["visit-start-action"].exists
            || app.buttons["visit-resume-action"].exists
            || app.buttons["visit-view-action"].exists
    }

    @MainActor
    private func focusAndType(_ text: String, in element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        XCTAssertTrue(element.isHittable)
        element.tap()
        if !waitForKeyboardFocus(in: element) {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        element.typeText(text)
    }

    @MainActor
    private func replaceText(with text: String, in element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        element.tap()
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 32))
        element.typeText(text)
    }

    @MainActor
    private func waitForKeyboardFocus(in element: XCUIElement) -> Bool {
        let focusExpectation = expectation(
            for: NSPredicate(format: "hasKeyboardFocus == true"),
            evaluatedWith: element
        )
        return XCTWaiter().wait(for: [focusExpectation], timeout: 2) == .completed
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

private struct ConnectedGraph {
    let clientName: String
    let primaryBarnName: String
    let secondaryBarnName: String
    let servicedHorseName: String
    let notServicedHorseName: String
}

private enum VisitOutcome {
    case pending
    case serviced
    case notServiced

    var title: String {
        switch self {
        case .pending:
            "Pending"
        case .serviced:
            "Serviced"
        case .notServiced:
            "Not Serviced"
        }
    }
}
