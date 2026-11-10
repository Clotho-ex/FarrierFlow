import XCTest

final class VisitExecutionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testPendingVisitPreservesCollapsedDraftPhotosAndCompletionAcrossRelaunch() {
        let app = launch()
        defer { app.terminate() }
        openPendingVisit(in: app)
        let summary = app.staticTexts["visit-progress-summary"]
        XCTAssertTrue(summary.label == "0 services recorded")
        XCTAssertTrue(app.staticTexts["visit-shared-client"].label.contains("Morgan Reed"))
        XCTAssertFalse(app.descendants(matching: .any)["visit-saved-total"].exists)
        XCTAssertFalse(app.buttons["visit-complete"].exists)
        XCTAssertTrue(app.buttons["visit-save-progress"].isHittable)
        expand("Milo", in: app)
        XCTAssertFalse(app.buttons["visit-outcome-Scout"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["visit-work-item-subtotal-Milo"].exists)
        capture("Visit pending, one horse expanded", in: app)
        let plan = app.buttons["visit-record-planned-Milo"]
        reveal(plan, in: app)
        plan.tap()
        select("Serviced", horse: "Milo", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["visit-draft-total"].exists)
        let notes = notesEditor("Milo", in: app)
        notes.tap()
        notes.typeText("Gate code 1428; rear shoe checked.")
        app.buttons["visit-dismiss-keyboard"].tap()
        let unsavedPhotos = app.buttons["visit-photographs-Milo"]
        reveal(unsavedPhotos, in: app)
        unsavedPhotos.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        app.navigationBars["Photos"].buttons["Visit"].tap()
        reveal(notes, in: app)
        XCTAssertEqual(notes.value as? String, "Gate code 1428; rear shoe checked.")
        app.buttons["visit-close"].tap()
        XCTAssertTrue(app.staticTexts["Discard Unsaved Changes?"].waitForExistence(timeout: 3))
        if app.buttons["Keep Editing"].exists { app.buttons["Keep Editing"].tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap() }
        expand("Scout", in: app)
        XCTAssertFalse(notes.exists)
        select("Not Serviced", horse: "Scout", in: app)
        XCTAssertFalse(app.buttons["Clear Recorded Work"].exists)
        XCTAssertTrue(app.buttons["visit-complete"].waitForExistence(timeout: 3))
        reveal(summary, in: app, towardTop: true)
        XCTAssertTrue(summary.label == "1 service recorded")
        app.buttons["visit-save-progress"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Delete Visit"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["visit-unsaved-state"].waitForNonExistence(timeout: 3))
        let total = app.descendants(matching: .any)["visit-saved-total"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        XCTAssertTrue(total.label.contains("$135.00"), total.label)
        app.buttons["visit-close"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForNonExistence(timeout: 3))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.selectFarrierFlowTab("Schedule")
        let appointment = app.buttons["appointment-row-Oak Ridge Farm"]
        reveal(appointment, in: app)
        appointment.tap()
        app.buttons["visit-resume-action"].tap()
        expand("Milo", in: app)
        _ = notesEditor("Milo", in: app)
        reveal(notes, in: app)
        XCTAssertEqual(notes.value as? String, "Gate code 1428; rear shoe checked.")
        app.buttons["visit-dismiss-keyboard"].tap()
        XCTAssertTrue(app.buttons["visit-complete"].waitForExistence(timeout: 3))
        let work = app.buttons["visit-work-item-Milo-Front Shoes"]
        reveal(work, in: app)
        XCTAssertTrue(work.exists)
        let photos = app.buttons["visit-photographs-Milo"]
        reveal(photos, in: app)
        XCTAssertTrue(photos.label.contains("Add Photo"), photos.label)
        XCTAssertFalse(photos.label.contains("0"), photos.label)
        XCTAssertLessThanOrEqual(photos.frame.maxY, app.buttons["visit-complete"].frame.minY)
        capture("Visit final controls above completion footer", in: app)
        photos.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Photos"].exists)
        app.navigationBars["Photos"].buttons["Visit"].tap()
        app.buttons["visit-actions-menu"].tap()
        app.buttons["Delete Visit"].tap()
        XCTAssertTrue(app.alerts["Delete Visit?"].waitForExistence(timeout: 3))
        capture("Visit native deletion alert", in: app)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Visit"].exists)
        app.buttons["visit-complete"].tap()
        XCTAssertTrue(app.navigationBars["Schedule Next Visit"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargestTextLeavesRoomToReviewVisit() {
        let app = launch(largestText: true)
        defer { app.terminate() }
        capture("Today active action visible at largest text", in: app)
        openActiveVisit(in: app)
        let complete = app.buttons["visit-complete"]
        let save = app.buttons["visit-save-progress"]
        XCTAssertTrue(complete.isHittable)
        XCTAssertTrue(save.exists)
        XCTAssertGreaterThan(complete.frame.minY, app.frame.height * 0.72,
                             "Visit actions must leave room to review the scrolling records.")
        XCTAssertLessThanOrEqual(save.frame.maxY, app.frame.maxY - 8)
        capture("Visit accessible action area leaves room for records", in: app)
    }

    @MainActor
    func testSafetyCollapsingAndFooterAtLargestTextInDarkMode() {
        let app = launch(largestText: true)
        defer { app.terminate() }
        openActiveVisit(in: app)
        let total = app.descendants(matching: .any)["visit-saved-total"].firstMatch
        reveal(total, in: app)
        XCTAssertTrue(total.label.contains("$355.00"), total.label)
        let atlas = app.buttons["visit-horse-toggle-Atlas"]
        reveal(atlas, in: app)
        XCTAssertTrue(atlas.label.contains("Jordan Ellis"))
        XCTAssertFalse(atlas.label.contains("watch the right-front flare"))
        let safety = app.staticTexts["visit-safety-notes-Atlas"]
        reveal(safety, in: app, towardTop: true)
        XCTAssertTrue(safety.label.contains("Atlas"), safety.label)
        XCTAssertTrue(safety.label.contains("watch the right-front flare"), safety.label)
        expand("Beacon", in: app)
        XCTAssertFalse(app.buttons["visit-work-item-Atlas-Full Set"].exists)
        reveal(atlas, in: app, towardTop: true)
        reveal(safety, in: app, towardTop: true)
        XCTAssertTrue(safety.isHittable)
        capture("Visit compact safety remains visible when horse collapsed AX dark", in: app)
        let photos = app.buttons["visit-photographs-Beacon"]
        reveal(photos, in: app)
        let complete = app.buttons["visit-complete"]
        XCTAssertTrue(complete.isHittable)
        let footer = app.otherElements["visit-footer"].firstMatch
        XCTAssertTrue(footer.exists)
        XCTAssertLessThanOrEqual(photos.frame.maxY, footer.frame.minY)
        capture("Visit Photos and footer remain separate AX dark", in: app)
        let notes = app.buttons["visit-work-notes-toggle-Beacon"]
        reveal(notes, in: app)
        XCTAssertLessThanOrEqual(notes.frame.maxY, footer.frame.minY)
        capture("Visit final Notes row above native action footer AX dark", in: app)
        reveal(photos, in: app, towardTop: true)
        photos.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        app.navigationBars["Photos"].buttons["Visit"].tap()
        app.buttons["visit-close"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSafetyHeaderRemainsReadableWithStandardText() {
        let app = launch()
        defer { app.terminate() }
        openActiveVisit(in: app)
        let header = app.buttons["visit-horse-toggle-Atlas"]
        reveal(header, in: app)
        XCTAssertLessThan(header.frame.height, 180)
        XCTAssertFalse(header.label.contains("watch the right-front flare"))
        let safety = app.staticTexts["visit-safety-notes-Atlas"]
        reveal(safety, in: app, towardTop: true)
        XCTAssertTrue(safety.label.contains("watch the right-front flare"), safety.label)
        XCTAssertTrue(safety.label.contains("Safety note for Atlas"), safety.label)
        XCTAssertGreaterThanOrEqual(safety.frame.minY, header.frame.maxY - 1)
        XCTAssertLessThan(safety.frame.minY - header.frame.maxY, 25)
        XCTAssertFalse(app.staticTexts["Safety Notes"].exists)
        let services = app.staticTexts["Services"]
        XCTAssertLessThanOrEqual(services.frame.minY - safety.frame.maxY, 24)
        capture("Visit compact warning directly below horse name", in: app)
        let photos = app.buttons["visit-photographs-Atlas"]
        reveal(photos, in: app)
        XCTAssertTrue(photos.label.contains("Add Photo"), photos.label)
        XCTAssertFalse(photos.label.contains("0"), photos.label)
        capture("Visit empty Add Photo row without a disclosure indicator", in: app)
        photos.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Photos"].exists)
        app.navigationBars["Photos"].buttons["Visit"].tap()
        XCTAssertTrue(photos.waitForExistence(timeout: 3))
    }

    @MainActor
    func testApplyWorkMenuCancellationPreservesIndependentHorseDrafts() {
        let app = launch()
        defer { app.terminate() }
        app.buttons["today-run-sheet-active"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        select("Choose", horse: "Clover", in: app)
        XCTAssertFalse(app.buttons["visit-complete"].exists)
        app.buttons["visit-actions-menu"].tap()
        let apply = app.buttons["visit-apply-work-action"]
        XCTAssertTrue(apply.waitForExistence(timeout: 3))
        apply.tap()
        let picker = app.navigationBars["Apply Work to Horses"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        picker.buttons["Cancel"].tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "visit-work-item-Clover-")).firstMatch.exists)
        expand("Atlas", in: app)
        XCTAssertTrue(app.buttons["visit-work-item-Atlas-Full Set"].exists)
        XCTAssertFalse(app.buttons["visit-work-item-Clover-Full Set"].exists)
    }

    @MainActor
    func testServiceSelectionAlwaysOpensAndRemovalUsesNativeConfirmation() {
        let app = launch()
        defer { app.terminate() }
        openPendingVisit(in: app)
        expand("Milo", in: app)
        let planned = app.buttons["visit-record-planned-Milo"]
        reveal(planned, in: app)
        planned.tap()
        for service in ["Trim", "Full Set"] {
            let add = app.buttons["visit-add-service-Milo"]
            reveal(add, in: app)
            add.tap()
            XCTAssertTrue(app.navigationBars["Add Service"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.navigationBars["New Service"].exists)
            let option = app.buttons["visit-service-option-\(service)"]
            reveal(option, in: app)
            option.tap()
            XCTAssertTrue(app.navigationBars["Add Service"].waitForNonExistence(timeout: 3))
        }
        XCTAssertFalse(app.descendants(matching: .any)["visit-work-item-subtotal-Milo"].exists)
        let add = app.buttons["visit-add-service-Milo"]
        reveal(add, in: app)
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Service"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Services Available"].exists)
        XCTAssertFalse(app.navigationBars["New Service"].exists)
        let create = app.buttons["visit-create-service-action"]
        reveal(create, in: app)
        XCTAssertTrue(create.label.contains("Create New Service"))
        create.tap()
        XCTAssertTrue(app.navigationBars["New Service"].waitForExistence(timeout: 3))
        app.navigationBars["New Service"].buttons["Cancel"].tap()
        app.navigationBars["Add Service"].buttons["Cancel"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["visit-saved-total"].exists)
        select("Serviced", horse: "Milo", in: app)
        app.buttons["visit-save-progress"].tap()
        let total = app.descendants(matching: .any)["visit-saved-total"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        XCTAssertTrue(total.label.contains("$410.00"), total.label)
        capture("Recorded total floats above Save Progress", in: app)
        let trim = app.buttons["visit-work-item-Milo-Trim"]
        reveal(trim, in: app)
        trim.tap()
        let remove = app.buttons["visit-remove-service"]
        reveal(remove, in: app)
        remove.tap()
        let confirmation = app.alerts["Remove Service?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        capture("Native remove recorded service confirmation", in: app)
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit Visit Service"].exists)
        remove.tap()
        confirmation.buttons["Remove Service"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Visit Service"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(trim.exists)
        let draftTotal = app.descendants(matching: .any)["visit-draft-total"].firstMatch
        XCTAssertTrue(draftTotal.label.contains("$355.00"), draftTotal.label)
        app.buttons["visit-save-progress"].tap()
        XCTAssertTrue(total.label.contains("$355.00"), total.label)
        reveal(app.buttons["visit-work-item-Milo-Front Shoes"], in: app)
        XCTAssertTrue(app.buttons["visit-work-item-Milo-Front Shoes"].exists)
    }

    @MainActor
    func testCompletedVisitPhotosRemainReadableAtLargestText() {
        let app = launch(largestText: true, scenario: "payment-pending")
        defer { app.terminate() }
        app.selectFarrierFlowTab("Schedule")
        let appointment = app.buttons["appointment-row-Invoice Service Location"].firstMatch
        reveal(appointment, in: app)
        appointment.tap()
        let visit = app.buttons["visit-view-action"]
        XCTAssertTrue(visit.waitForExistence(timeout: 3))
        reveal(visit, in: app)
        XCTAssertTrue(visit.isHittable)
        XCTAssertEqual(app.descendants(matching: .any)["appointment-summary"].firstMatch.value as? String, "Completed")
        capture("Completed Appointment pill AX dark", in: app)
        visit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let photos = app.buttons["visit-result-photographs-Milo"]
        reveal(photos, in: app)
        XCTAssertTrue(photos.label.contains("Photos"))
        XCTAssertTrue(photos.label.contains("0 photos"))
        capture("Completed visit Photos at largest text", in: app)
        photos.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testNativeDeleteVisitKeepsExistingLinkedRecordConfirmation() {
        let app = launch()
        defer { app.terminate() }
        openPendingVisit(in: app)
        app.buttons["visit-actions-menu"].tap()
        XCTAssertTrue(app.buttons["Directions"].exists)
        app.buttons["Delete Visit"].tap()
        let alert = app.alerts["Delete Visit?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "its appointment")).firstMatch.exists)
        alert.buttons["Delete Visit"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Appointment Unavailable"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.selectFarrierFlowTab("Schedule")
        XCTAssertFalse(app.buttons["appointment-row-Oak Ridge Farm"].exists)
        XCTAssertTrue(app.buttons["appointment-row-Cedar Run Equestrian"].exists)
    }

    @MainActor
    private func launch(largestText: Bool = false, scenario: String = "app-store-showcase") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "VisitExecution-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = scenario
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
    private func openActiveVisit(in app: XCUIApplication) {
        let active = app.buttons["today-run-sheet-active"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        let action = active.staticTexts["Resume Visit"].firstMatch
        if action.exists {
            XCTAssertTrue(action.isHittable)
            XCTAssertLessThanOrEqual(action.frame.maxY, app.tabBars.firstMatch.frame.minY)
            action.tap()
        } else {
            active.tap()
        }
        if !app.navigationBars["Visit"].waitForExistence(timeout: 5), active.exists {
            active.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openPendingVisit(in app: XCUIApplication) {
        app.selectFarrierFlowTab("Schedule")
        let appointment = app.buttons["appointment-row-Oak Ridge Farm"]
        reveal(appointment, in: app)
        appointment.tap()
        let start = app.buttons["visit-start-action"]
        reveal(start, in: app)
        start.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func notesEditor(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let editor = app.descendants(matching: .any)["visit-work-notes-\(name)"].firstMatch
        if !editor.exists {
            let toggle = app.buttons["visit-work-notes-toggle-\(name)"]
            reveal(toggle, in: app)
            toggle.tap()
        }
        reveal(editor, in: app)
        return editor
    }

    @MainActor
    private func expand(_ name: String, in app: XCUIApplication) {
        let outcome = app.descendants(matching: .any)["visit-outcome-\(name)"].firstMatch
        if !outcome.exists {
            let toggle = app.buttons["visit-horse-toggle-\(name)"]
            reveal(toggle, in: app)
            toggle.tap()
        }
        reveal(outcome, in: app)
    }

    @MainActor
    private func select(_ value: String, horse: String, in app: XCUIApplication) {
        expand(horse, in: app)
        let outcome = app.descendants(matching: .any)["visit-outcome-\(horse)"].firstMatch
        let choice = app.buttons.matching(NSPredicate(format: "label == %@", value))
        if !choice.allElementsBoundByIndex.contains(where: \.isHittable) { outcome.tap() }
        XCTAssertTrue(choice.firstMatch.waitForExistence(timeout: 3))
        guard let target = choice.allElementsBoundByIndex.first(where: \.isHittable) else {
            XCTFail("Expected visible work outcome \(value)"); return
        }
        target.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        for _ in 0..<14 {
            let navigationBar = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).max {
                $0.frame.maxY < $1.frame.maxY
            }
            let top = navigationBar?.frame.maxY ?? 100
            let isVisit = navigationBar?.identifier == "Visit"
            let footer = isVisit ? [app.buttons["visit-complete"], app.buttons["visit-save-progress"]]
                .first { $0.exists && $0.isHittable && $0.frame.minY > app.frame.midY } : nil
            let actionArea = app.otherElements["visit-footer"].firstMatch
            let footerTop = isVisit && actionArea.exists ? actionArea.frame.minY : footer?.frame.minY ?? app.frame.maxY
            let bottom = min(footerTop, app.keyboards.firstMatch.exists
                             ? app.keyboards.firstMatch.frame.minY : app.frame.maxY)
            let frame = element.exists ? element.frame : .zero
            let fits = frame.height <= bottom - top - 8
            let visible = fits ? frame.minY >= top + 4 && frame.maxY <= bottom - 4
                : frame.midY > top + 4 && frame.midY < bottom - 4
            if element.exists, element.isHittable, visible { return }
            let scrollDown: Bool
            let distance: CGFloat
            let limit = (bottom - top) * 0.6
            if element.exists {
                let offset = fits
                    ? (frame.minY < top + 8 ? top + 16 - frame.minY : bottom - 16 - frame.maxY)
                    : (top + bottom) / 2 - frame.midY
                scrollDown = offset > 0
                distance = min(max(abs(offset), 20), limit)
            } else {
                scrollDown = towardTop
                distance = limit
            }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let center = (top + bottom) / 2
            let upper = origin.withOffset(CGVector(dx: 18, dy: center - distance / 2))
            let lower = origin.withOffset(CGVector(dx: 18, dy: center + distance / 2))
            if scrollDown {
                upper.press(forDuration: 0.05, thenDragTo: lower, withVelocity: .slow, thenHoldForDuration: 0.2)
            } else {
                lower.press(forDuration: 0.05, thenDragTo: upper, withVelocity: .slow, thenHoldForDuration: 0.2)
            }
        }
        capture("Visit execution scroll failure", in: app)
        XCTFail("Expected visible element: \(element); \(app.debugDescription)")
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
