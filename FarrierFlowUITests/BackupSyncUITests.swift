import XCTest

final class BackupSyncUITests: XCTestCase {
    @MainActor
    func testBackupSettingsHierarchyIsCompactAndNative() {
        verifySettingsHierarchy(dark: false, accessibility: false)
    }

    @MainActor
    func testBackupSettingsHierarchyRemainsReadableInDarkModeAtAccessibilityXXXL() {
        verifySettingsHierarchy(dark: true, accessibility: true)
    }

    @MainActor
    func testSignOutStillRequiresConfirmationFromTheCautionGroup() {
        let app = openCloudFixture(state: "connected")
        defer { app.terminate() }
        let signOut = app.buttons["backup-sync-sign-out"]
        for _ in 0..<8 where !signOut.isHittable { app.swipeUp() }
        XCTAssertTrue(signOut.isHittable)
        guard signOut.isHittable else { return }
        signOut.tap()
        XCTAssertTrue(app.staticTexts["Stop syncing this iPhone?"].waitForExistence(timeout: 3))
        attachHistoryScreenshot(app, name: "Sign out confirmation")
        let cancel = app.buttons["Cancel"]
        if cancel.exists && cancel.isHittable { cancel.tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.10)).tap() }
        XCTAssertTrue(signOut.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["backup-sync-sign-in"].exists)
    }

    @MainActor
    private func verifySettingsHierarchy(dark: Bool, accessibility: Bool) {
        let app = openCloudFixture(state: "connected", dark: dark, accessibility: accessibility)
        defer { app.terminate() }
        let backup = app.staticTexts["backup-sync-backup-heading"]
        XCTAssertTrue(backup.waitForExistence(timeout: 3))
        guard backup.exists else { return }
        XCTAssertFalse(app.tabBars.element.exists, "The settings detail should hide the app tab bar.")
        let status = app.descendants(matching: .any)["backup-sync-status"]
        XCTAssertTrue(status.exists)
        XCTAssertTrue(status.label.contains("Everything is backed up"))
        let retry = app.buttons["backup-sync-retry"]
        for _ in 0..<8 where !retry.isHittable { app.swipeUp() }
        XCTAssertTrue(retry.isHittable)
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
        XCTAssertTrue(app.staticTexts["backup-sync-protection-explanation"].exists)
        attachHistoryScreenshot(app, name: "Backup settings \(dark ? "Dark XXXL" : "Light")")

        let signOut = app.buttons["backup-sync-sign-out"]
        for _ in 0..<10 where !signOut.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["backup-sync-account-heading"].exists)
        XCTAssertTrue(signOut.isHittable)
        guard signOut.exists else { return }
        XCTAssertGreaterThanOrEqual(signOut.frame.height, 44)
        XCTAssertLessThan(retry.frame.midY, signOut.frame.midY,
            "Manual sync should remain in the backup group above the lower-priority sign-out row.")

        let delete = app.buttons["backup-sync-delete"]
        for _ in 0..<10 where !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["backup-sync-danger-heading"].exists)
        XCTAssertTrue(app.staticTexts["backup-sync-delete-hint"].exists)
        XCTAssertTrue(delete.isHittable)
        guard delete.exists else { return }
        XCTAssertGreaterThanOrEqual(delete.frame.height, 44)
        attachHistoryScreenshot(app, name: "Account and danger zones \(dark ? "Dark XXXL" : "Light")")
    }

    @MainActor
    func testReadOnlyBusinessStillScrollsToDefaults() {
        let app = openCloudFixture(state: "connected", dark: true, accessibility: true)
        defer { app.terminate() }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["More"].tap()
        app.buttons["My Business"].tap()
        XCTAssertTrue(app.navigationBars["My Business"].waitForExistence(timeout: 3))
        let note = app.textFields["business-profile-default-invoice-note-field"]
        let multiline = app.textViews["business-profile-default-invoice-note-field"]
        for _ in 0..<8 where !note.isHittable && !multiline.isHittable { app.swipeUp() }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "My Business read-only Dark XXXL"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(note.isHittable || multiline.isHittable, "Read-only business details must remain scrollable.")
        XCTAssertFalse(app.buttons["business-profile-save-action"].exists)
        if note.exists { XCTAssertFalse(note.isEnabled) }
        if multiline.exists { XCTAssertFalse(multiline.isEnabled) }
    }

    @MainActor
    func testOfflineRetryKeepsTheSyncActionInPlace() {
        verifyOfflineRetryPosition(accessibility: false)
    }

    @MainActor
    func testOfflineRetryKeepsTheSyncActionInPlaceAtAccessibilityXXXL() {
        verifyOfflineRetryPosition(accessibility: true)
    }

    @MainActor
    private func verifyOfflineRetryPosition(accessibility: Bool) {
        let app = openCloudFixture(state: "offline", accessibility: accessibility)
        defer { app.terminate() }
        let retry = app.buttons["backup-sync-retry"]
        for _ in 0..<8 where !retry.isHittable { app.swipeUp() }
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.wait(for: \.isEnabled, toEqual: true, timeout: 8))
        let before = retry.frame.midY
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Backup offline before retry"
        shot.lifetime = .keepAlways
        add(shot)
        retry.tap()
        XCTAssertTrue(retry.wait(for: \.isEnabled, toEqual: false, timeout: 2))
        XCTAssertEqual(retry.frame.midY, before, accuracy: 2, "Retry must not move the action while status changes.")
        XCTAssertTrue(retry.wait(for: \.isEnabled, toEqual: true, timeout: 8))
        XCTAssertEqual(retry.frame.midY, before, accuracy: 2)
    }

    @MainActor
    func testLocalHistoryIsReadOnlyAndExportableWithoutProOrSignIn() {
        let app = openCloudFixture(state: "history")
        defer { app.terminate() }
        let history = app.buttons["backup-sync-local-history"]
        for _ in 0..<10 where !history.isHittable { app.swipeUp() }
        XCTAssertTrue(history.isHittable)
        guard history.isHittable else { return }
        history.tap()
        XCTAssertTrue(app.navigationBars["Invoice History"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["invoice-history-explanation"].exists)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "invoice-history-row-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        guard row.exists else { return }
        row.tap()
        XCTAssertTrue(app.staticTexts["Not cloud-protected"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["invoice-mark-paid-action"].exists)
        XCTAssertFalse(app.buttons["invoice-delete-action"].exists)
        for _ in 0..<12 where !app.buttons["invoice-history-share"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["invoice-history-share"].isEnabled)
        app.buttons["invoice-history-share"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["invoice-history-share"].exists)
    }

    @MainActor
    func testRecoveryNeedsExplicitSettingsAndConfirmation() {
        let app = openCloudFixture(state: "recovery")
        defer { app.terminate() }
        let review = app.buttons["backup-sync-review"]
        for _ in 0..<8 where !review.isHittable { app.swipeUp() }
        XCTAssertTrue(review.isHittable)
        guard review.isHittable else { return }
        attachHistoryScreenshot(app, name: "Backup recovery status")
        review.tap()
        app.buttons["backup-sync-invoice-recovery"].tap()
        XCTAssertTrue(app.navigationBars["Review Invoice History"].waitForExistence(timeout: 5))
        let save = app.buttons["invoice-recovery-continue"]
        for _ in 0..<10 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.exists && !save.isEnabled)
        for _ in 0..<8 where !app.buttons["Use Cloud Settings"].isHittable { app.swipeDown() }
        app.buttons["Use Cloud Settings"].tap()
        for _ in 0..<10 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@",
            "Original invoices stay on this iPhone only.")).firstMatch.waitForExistence(timeout: 3))
        // iOS 26 adapts confirmationDialog to a native popover on this phone;
        // cancellation is an outside tap, not a rendered Cancel row.
        let cancel = app.buttons["Cancel"]
        if cancel.exists && cancel.isHittable { cancel.tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.10)).tap() }
        XCTAssertTrue(save.exists)
        save.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@",
            "Keep History & Continue", "invoice-recovery-continue")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Review Changes"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let history = app.buttons["backup-sync-local-history"]
        for _ in 0..<10 where !history.isHittable { app.swipeUp() }
        XCTAssertTrue(history.isHittable)
    }
    @MainActor
    func testCloudDeletionRequiresConfirmationAndKeepsTheNativeAppleStep() {
        let app = openCloudFixture(state: "connected")
        defer { app.terminate() }
        let delete = app.buttons["backup-sync-delete"]
        for _ in 0..<8 where !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(delete.exists)
        guard delete.exists else { return }
        delete.tap()
        let confirm = app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", "Delete Cloud Account", "backup-sync-delete"
        )).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Delete Cloud Account"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["backup-sync-deletion-retention"].exists)
        XCTAssertTrue(app.buttons["backup-sync-deletion-apple"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["backup-sync-delete"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["backup-sync-deletion-state"].exists)
    }

    @MainActor
    func testQueuedDeletionCanConfirmCompletionWithoutOfferingOrdinarySignIn() {
        let app = openCloudFixture(state: "pending")
        defer { app.terminate() }
        let progress = app.staticTexts["backup-sync-deletion-state"]
        for _ in 0..<8 where !progress.isHittable { app.swipeUp() }
        XCTAssertTrue(progress.exists)
        XCTAssertFalse(app.buttons["backup-sync-sign-in"].exists)
        let check = app.buttons["backup-sync-deletion-check"]
        for _ in 0..<4 where !check.isHittable { app.swipeUp() }
        XCTAssertTrue(check.isHittable)
        guard check.isHittable else { return }
        check.tap()
        XCTAssertTrue(app.staticTexts["Cloud account deletion is complete. Your records and photos on this iPhone have been kept."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["backup-sync-sign-in"].exists)
    }

    @MainActor
    func testHistoryEntryPointsAtAccessibilityXXXLInDarkMode() {
        let app = openCloudFixture(state: "history", dark: true, accessibility: true)
        defer { app.terminate() }
        let history = app.buttons["backup-sync-local-history"]
        for _ in 0..<12 where !history.exists || !history.isHittable { app.swipeUp() }
        XCTAssertTrue(history.isHittable)
        guard history.isHittable else { return }
        history.tap()
        guard verifyHistoryDetailAndReturn(app, export: true) else { return }
        XCTAssertTrue(app.navigationBars["Backup & Sync"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openInvoiceListHistory(app)
        guard verifyHistoryDetailAndReturn(app, export: false) else { return }
        XCTAssertTrue(app.navigationBars["Invoices"].waitForExistence(timeout: 3))

        // Reopen the same persisted archive, without either fixture reseeder.
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_CLOUD_STATE")
        app.launch()
        selectClients(app)
        openInvoiceListHistory(app)
        guard verifyHistoryDetailAndReturn(app, export: false) else { return }
        XCTAssertTrue(app.navigationBars["Invoices"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openInvoiceListHistory(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 3))
        app.buttons["More"].press(forDuration: 0.15)
        XCTAssertTrue(app.buttons["Invoices"].waitForExistence(timeout: 3))
        app.buttons["Invoices"].press(forDuration: 0.15)
        XCTAssertTrue(app.navigationBars["Invoices"].waitForExistence(timeout: 3))
        let history = app.buttons["Invoice History"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()
    }

    @MainActor
    private func verifyHistoryDetailAndReturn(_ app: XCUIApplication, export: Bool) -> Bool {
        XCTAssertTrue(app.navigationBars["Invoice History"].waitForExistence(timeout: 3))
        attachHistoryScreenshot(app, name: "History Dark XXXL List")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "invoice-history-row-")).firstMatch
        // At accessibility5 the explanation fills the first screen, so the
        // native List has not materialized the invoice row until it is scrolled.
        for _ in 0..<12 where !row.exists || !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        guard row.exists else { return false }
        attachHistoryScreenshot(app, name: "History Dark XXXL Invoice Row")
        row.tap()
        XCTAssertTrue(app.staticTexts["Not cloud-protected"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["invoice-mark-paid-action"].exists)
        XCTAssertFalse(app.buttons["invoice-delete-action"].exists)
        attachHistoryScreenshot(app, name: "History Dark XXXL Detail")
        if export {
            let share = app.buttons["invoice-history-share"]
            for _ in 0..<20 where !share.exists || !share.isHittable { app.swipeUp() }
            XCTAssertTrue(share.isHittable && share.isEnabled)
            guard share.isHittable else { return false }
            attachHistoryScreenshot(app, name: "History Dark XXXL Export Action")
            share.tap()
            let close = app.buttons["Close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            close.tap()
            // The system share UI is hosted by another process. App-idle does
            // not imply its dismissal completed; don't tap a covered Back.
            XCTAssertTrue(close.waitForNonExistence(timeout: 5))
            guard !close.exists else { return false }
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Invoice History"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        return true
    }

    @MainActor
    private func attachHistoryScreenshot(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    private func openCloudFixture(state: String, dark: Bool = false, accessibility: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "CloudDeletion-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "app-store-showcase"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_CLOUD_STATE"] = state
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        if dark { app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark" }
        if accessibility { app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        selectClients(app)
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 3))
        app.buttons["More"].press(forDuration: 0.15)
        XCTAssertTrue(app.buttons["backup-sync-open"].waitForExistence(timeout: 3))
        app.buttons["backup-sync-open"].press(forDuration: 0.15)
        XCTAssertTrue(app.navigationBars["Backup & Sync"].waitForExistence(timeout: 3))
        return app
    }

    @MainActor
    private func selectClients(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Clients"].waitForExistence(timeout: 5))
        let clients = app.tabBars.buttons["Clients"]
        if #available(iOS 26, *) {
            // The floating tab accepts its normal center, not its lower label.
            clients.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.15)
        } else {
            // The legacy runner's default point can land above the active area.
            clients.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
        }
        if !app.navigationBars["Clients"].waitForExistence(timeout: 3),
           !app.tabBars.buttons["Clients"].isSelected {
            // A launch-time iOS 18 snapshot can still use the previous tab
            // geometry. Retry at the lower interior only after observing that
            // the original tap did not select Clients.
            if #available(iOS 26, *) {
                clients.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                clients.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
            }
        }
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOptionalBackupIsAccessibleWithoutProInLightMode() {
        verifyAccountSurface(dark: false, accessibility: false)
    }

    @MainActor
    func testOptionalBackupIsReadableInDarkMode() {
        verifyAccountSurface(dark: true, accessibility: false)
    }

    @MainActor
    func testOptionalBackupIsReadableAtAccessibilityXXXL() {
        verifyAccountSurface(dark: true, accessibility: true)
    }

    @MainActor
    func testRestoreEntryIsAvailableBeforeBusinessSetupOrPurchase() {
        verifyRestoreEntry(accessibility: false)
    }

    @MainActor
    func testRestoreSheetKeepsLargestAccessibilityTextSize() {
        verifyRestoreEntry(accessibility: true)
    }

    @MainActor
    private func verifyRestoreEntry(accessibility: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "BackupFresh-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        if accessibility { app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5" }
        app.launch()
        defer { app.terminate() }
        let restore = app.buttons["backup-sync-restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        guard restore.exists else { return }
        restore.tap()
        XCTAssertTrue(app.navigationBars["Backup & Sync"].waitForExistence(timeout: 3))
        if accessibility {
            let benefits = app.staticTexts["backup-sync-benefits"]
            XCTAssertTrue(benefits.waitForExistence(timeout: 3))
            XCTAssertGreaterThan(benefits.frame.height, 80, "The restore sheet must inherit the presenting screen’s Dynamic Type size.")
        }
        XCTAssertFalse(app.navigationBars["FarrierFlow Pro"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-welcome"].exists)
    }

    @MainActor
    private func verifyAccountSurface(dark: Bool, accessibility: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "BackupSurface-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "app-store-showcase"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = dark ? "dark" : "light"
        if accessibility { app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.tabBars.buttons["Clients"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Clients"].tap()
        app.buttons["More"].tap()
        let backup = app.buttons["backup-sync-open"]
        XCTAssertTrue(backup.waitForExistence(timeout: 3))
        backup.tap()
        XCTAssertTrue(app.navigationBars["Backup & Sync"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["backup-sync-benefits"].exists)
        let signIn = app.buttons["backup-sync-sign-in"]
        for _ in 0..<6 where !signIn.isHittable { app.swipeUp() }
        XCTAssertTrue(signIn.exists)
        XCTAssertFalse(signIn.isEnabled, "The isolated UI host must not authenticate against Dev.")
        XCTAssertGreaterThanOrEqual(signIn.frame.height, 44)
        let privacy = app.staticTexts["backup-sync-privacy"]
        for _ in 0..<6 where !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Backup & Sync \(dark ? "Dark" : "Light") \(accessibility ? "XXXL" : "Default")"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
