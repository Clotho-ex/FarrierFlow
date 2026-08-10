# FarrierFlow 1.0 Revenue Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `farrierflow-slice-driver` for each explicitly authorized unit,
> `superpowers:test-driven-development` for behavior changes, and
> `superpowers:verification-before-completion` before reporting a unit or the
> release complete. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship FarrierFlow 1.0 as a free App Store download with a reliable
monthly/yearly subscription, permanent read-only access to existing data after
entitlement loss, and the complete implemented farrier workflow ready to earn
revenue.

**Architecture:** Start from `origin/main`, port only the independently required
Appointment integrity fix, and introduce one StoreKit-owned Subscription
feature. A verified-current-entitlement source feeds one main-actor observable
access model; root routing and existing feature views use that model to permit
or remove mutation. SwiftData and canonical Photograph files remain unchanged
and readable in every access state.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, Observation, SwiftData,
StoreKit 2, `SubscriptionStoreView`, Swift Testing/XCTest, StoreKit Testing in
Xcode, iOS 18.0 minimum, iPhone only, Xcode 26.6 and latest stable iOS 26 SDK.

## Global Constraints

- Implement only
  `docs/superpowers/specs/2026-08-10-v1-revenue-release-design.md` after the
  specific unit is explicitly authorized in `.agents/workflow/CURRENT_UNIT.md`.
- Base release work on `origin/main`. Do not merge
  `codex/slice-8-unit-2-export-snapshot` or port its export mutation coordinator.
- Preserve the 14-model `FarrierFlowSchemaV1`. Add no SwiftData model, field,
  relationship, migration, or entitlement persistence.
- Use exact product identifiers:
  `com.farrierflow.yusufcan.FarrierFlow.pro.monthly` and
  `com.farrierflow.yusufcan.FarrierFlow.pro.yearly`.
- Use one subscription group, US prices $14.99/month and $119.99/year, a
  14-day introductory trial, and a 16-day billing grace period.
- Grant full access only from a verified current entitlement. Trial and grace
  are included by StoreKit current entitlements; billing retry outside grace,
  expiration, revocation, refund, missing, and unverified transactions are read
  only.
- Read-only mode preserves all record navigation, photographs, history, and PDF
  generation/viewing/printing/sharing from existing persisted Invoices. It
  permits no ordinary business-record or Photograph mutation.
- Add no FarrierFlow networking, account, server receipt validation, analytics,
  advertising, third-party package, generalized Settings, or custom paywall
  framework.
- Use native `SubscriptionStoreView`, `NavigationStack`, `List`, `Form`,
  `Section`, buttons, sheets, alerts, and accessibility behavior.
- New source files are discovered by synchronized Xcode groups. Edit
  `project.pbxproj` only for required build settings or resource membership.
- Use one simulator and run every Xcode command serially with
  `-parallel-testing-enabled NO -maximum-parallel-testing-workers 1`.
- Resolve destinations before execution. The currently verified destinations
  are:

  ```bash
  IOS18_DESTINATION='platform=iOS Simulator,id=02DB4E38-DF46-4F30-A8C8-C4D4DF46FDA4'
  IOS26_DESTINATION='platform=iOS Simulator,id=A9501C1D-4747-4310-8F2B-F0587E0E30C6'
  ```

- After every simulator command, stop the app/test runner, shut down that
  simulator, quit Simulator, and confirm no task-owned `xcodebuild`, `xctest`,
  or `XCTRunner` remains.
- Before every unit commit, run `git diff --check`, stage only the unit's files,
  inspect `git diff --cached --check` and the complete staged diff, and never
  stage `.agents/workflow/CURRENT_UNIT.md`.
- Do not push, begin the next unit, configure paid App Store state, upload a
  build, or submit for review without its separate explicit authorization.

---

## Task 1 — Unit 1 — Shipping-Baseline Appointment Integrity

**Goal:** Prevent an invalid stale Horse selection from inserting a partial new
Appointment or poisoning a corrected retry.

**Files:**

- Modify: `FarrierFlow/Features/Schedule/AppointmentEditorModel.swift`
- Test: `FarrierFlowTests/Features/Schedule/AppointmentEditorModelTests.swift`

**Interfaces:**

- Consumes: existing `AppointmentEditorModel.save(in:)`,
  `AppointmentRules.validate`, and `DomainGraphValidator.save`.
- Produces: unchanged public signature
  `func save(in context: ModelContext) -> PersistentIdentifier?` with insertion
  delayed until selected-Horse validation succeeds.

- [ ] **Step 1: Add the stale-selection regression test**

  Add this test using the existing `makeTwoHorseFixture()` helper and current
  no-coordinator save signature:

  ```swift
  @Test
  func staleHorseSelectionDoesNotLeakAnAppointmentOrBlockASubsequentSave() throws {
      let fixture = try makeTwoHorseFixture()
      let editor = AppointmentEditorModel()
      editor.load(in: fixture.context)
      editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
      editor.toggleHorse(fixture.horses[0].persistentModelID)
      let otherBarn = Barn(name: "South Field")
      fixture.context.insert(otherBarn)
      fixture.horses[0].currentBarn = otherBarn
      otherBarn.horses.append(fixture.horses[0])
      try DomainGraphValidator.save(fixture.context)

      #expect(editor.save(in: fixture.context) == nil)
      #expect(editor.alert?.title == "Review Selected Horses")
      #expect(try fixture.context.fetchCount(FetchDescriptor<Appointment>()) == 0)

      editor.draft.selectedHorseIDs = [fixture.horses[1].persistentModelID]
      let savedID = try #require(editor.save(in: fixture.context))
      let appointment = try #require(
          fixture.context.model(for: savedID) as? Appointment
      )
      #expect(try fixture.context.fetchCount(FetchDescriptor<Appointment>()) == 1)
      #expect(
          appointment.appointmentHorses.compactMap(\.horse?.persistentModelID)
              == [fixture.horses[1].persistentModelID]
      )
  }
  ```

- [ ] **Step 2: Run the focused test and verify RED**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/AppointmentEditorModelTests/staleHorseSelectionDoesNotLeakAnAppointmentOrBlockASubsequentSave\(\)
  ```

  Expected: failure because the current implementation inserts a new
  Appointment before rejecting the stale selection.

- [ ] **Step 3: Delay insertion until validation succeeds**

  Replace the early new-Appointment insertion with an optional existing value:

  ```swift
  let existingAppointment: Appointment?
  if let appointmentID {
      guard let existing = context.model(for: appointmentID) as? Appointment else {
          return nil
      }
      // Preserve the existing Visit-lock branch unchanged.
      existingAppointment = existing
  } else {
      existingAppointment = nil
  }

  // Resolve and validate selected Horses here, before insertion.

  let appointment: Appointment
  if let existingAppointment {
      appointment = existingAppointment
  } else {
      appointment = Appointment(startDate: draft.startDate, barn: barn)
      context.insert(appointment)
  }
  ```

  Preserve every existing alert, lock rule, normalization, relationship update,
  save, and rollback behavior.

- [ ] **Step 4: Run the complete Appointment editor suite**

  Run the selector above, then:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/AppointmentEditorModelTests
  ```

  Expected: all tests pass and the regression fetch count is exactly one after
  the corrected retry.

- [ ] **Step 5: Audit and commit Unit 1**

  ```bash
  git diff --check
  git add FarrierFlow/Features/Schedule/AppointmentEditorModel.swift \
    FarrierFlowTests/Features/Schedule/AppointmentEditorModelTests.swift
  git diff --cached --check
  git diff --cached
  git commit -m "fix(schedule): avoid leaking stale appointments"
  ```

---

## Task 2 — Unit 2 — Verified StoreKit Entitlement Core

**Goal:** Convert verified StoreKit current transactions into a small,
testable loading/full/read-only access state and observe changes while the app
runs.

**Files:**

- Create: `FarrierFlow/Features/Subscription/SubscriptionProduct.swift`
- Create: `FarrierFlow/Features/Subscription/SubscriptionAccess.swift`
- Create:
  `FarrierFlow/Features/Subscription/SubscriptionEntitlementSource.swift`
- Create:
  `FarrierFlow/Features/Subscription/StoreKitSubscriptionEntitlementSource.swift`
- Create: `FarrierFlow/Features/Subscription/SubscriptionAccessModel.swift`
- Test: `FarrierFlowTests/Features/Subscription/SubscriptionAccessModelTests.swift`

**Interfaces:**

- Produces exact product constants, a `SubscriptionAccess` value, one narrow
  test seam, a StoreKit implementation, and a main-actor environment model:

  ```swift
  enum SubscriptionProduct {
      static let monthly =
          "com.farrierflow.yusufcan.FarrierFlow.pro.monthly"
      static let yearly =
          "com.farrierflow.yusufcan.FarrierFlow.pro.yearly"
      static let identifiers: Set<String> = [monthly, yearly]
      static let orderedIdentifiers = [yearly, monthly]
  }

  nonisolated enum SubscriptionAccess: Equatable, Sendable {
      case loading
      case full
      case readOnly

      var allowsMutations: Bool { self == .full }
  }

  protocol SubscriptionEntitlementSource: Sendable {
      func hasCurrentEntitlement(productIDs: Set<String>) async -> Bool
      func updates(productIDs: Set<String>) async -> AsyncStream<Void>
  }

  @MainActor @Observable
  final class SubscriptionAccessModel {
      private(set) var access: SubscriptionAccess = .loading
      var allowsMutations: Bool { access.allowsMutations }
      init(source: any SubscriptionEntitlementSource)
      func start()
      func refresh() async
  }

  nonisolated struct StoreKitSubscriptionEntitlementSource:
      SubscriptionEntitlementSource {
      func hasCurrentEntitlement(productIDs: Set<String>) async -> Bool
      func updates(productIDs: Set<String>) async -> AsyncStream<Void>
  }
  ```

- [ ] **Step 1: Write access-model RED tests with a controllable source**

  In the test file, define an actor fake that exposes current entitlement and an
  `AsyncStream` continuation. Cover:

  ```swift
  @Test @MainActor
  func verifiedCurrentEntitlementGrantsFullAccess() async {
      let source = TestSubscriptionEntitlementSource(hasEntitlement: true)
      let model = SubscriptionAccessModel(source: source)

      await model.refresh()

      #expect(model.access == .full)
      #expect(model.allowsMutations)
  }

  @Test @MainActor
  func missingEntitlementIsReadOnly() async {
      let source = TestSubscriptionEntitlementSource(hasEntitlement: false)
      let model = SubscriptionAccessModel(source: source)

      await model.refresh()

      #expect(model.access == .readOnly)
      #expect(!model.allowsMutations)
  }
  ```

  Also prove `start()` is idempotent, an emitted update refreshes full → read
  only and read only → full, cancellation ends the listener, and unrelated
  product identifiers never grant access.

- [ ] **Step 2: Run tests and verify missing-type RED**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/SubscriptionAccessModelTests
  ```

  Expected: compilation fails because Subscription types do not exist.

- [ ] **Step 3: Implement the value and observable model**

  `SubscriptionAccessModel.start()` creates exactly one task, calls `refresh`,
  then refreshes for every source update. Do not persist the result. Cancel the
  task in `deinit`.

- [ ] **Step 4: Implement the StoreKit source**

  On iOS 18.4 and later, `hasCurrentEntitlement` iterates
  `Transaction.currentEntitlements(for:)` once for each approved product
  identifier. On iOS 18.0 through 18.3, use the global
  `Transaction.currentEntitlements` sequence from a compatibility helper whose
  availability ends before iOS 18.4, so the current SDK emits no deprecation
  diagnostic. Both paths accept only `.verified` transactions whose
  `productID` is in the approved set and return false when no approved sequence
  yields one. Do not require product-merchandising metadata and do not
  separately grant billing-retry access: StoreKit current entitlements already
  include only subscribed and grace-period auto-renewable subscriptions.

  `updates` wraps `Transaction.updates` in an `AsyncStream<Void>`, ignores
  unverified and unrelated results, yields for a verified approved product, and
  finishes that verified transaction after yielding. Cancellation of the
  stream cancels its listener task.

- [ ] **Step 5: Run focused GREEN and mutation check**

  Run the Unit 2 selector. Then temporarily make
  `hasCurrentEntitlement` always return true and confirm the missing-entitlement
  test fails. Restore production code and rerun the selector to green.

- [ ] **Step 6: Audit and commit Unit 2**

  Stage only the six Unit 2 files and commit:

  ```bash
  git commit -m "feat(subscription): resolve verified access"
  ```

---

## Task 3 — Unit 3 — Subscription Store and Root Routing

**Goal:** Present native monthly/yearly purchasing, restore/manage actions, and
the correct first-launch or returning-user root state.

**Files:**

- Create: `FarrierFlow/Features/Subscription/SubscriptionRoutes.swift`
- Create: `FarrierFlow/Features/Subscription/SubscriptionRootRules.swift`
- Create: `FarrierFlow/Features/Subscription/Views/SubscriptionView.swift`
- Create:
  `FarrierFlow/Features/Subscription/Views/SubscriptionWelcomeView.swift`
- Create:
  `FarrierFlow/Features/Subscription/Views/SubscriptionReadOnlyNotice.swift`
- Modify: `FarrierFlow/App/FarrierFlowApp.swift`
- Modify: `FarrierFlow/App/RootView.swift`
- Modify: `FarrierFlow/App/UITestLaunchConfiguration.swift`
- Modify: `FarrierFlow/Features/Clients/Views/ClientListView.swift`
- Modify: `FarrierFlow/Features/Today/Views/TodayView.swift`
- Test: `FarrierFlowTests/Features/Subscription/SubscriptionRootStateTests.swift`
- Test: `FarrierFlowUITests/SubscriptionFlowUITests.swift`

**Interfaces:**

  ```swift
  enum SubscriptionRoute: Hashable { case store }

  enum SubscriptionRootState: Equatable {
      case loading
      case subscriptionWelcome
      case ownerSetup
      case app(readOnly: Bool)
  }

  nonisolated enum SubscriptionRootRules {
      static func state(
          access: SubscriptionAccess,
          hasIdentity: Bool
      ) -> SubscriptionRootState
  }

  enum SubscriptionUITestAccess: String {
      case full
      case readOnly
  }
  ```

  A small actor-neutral rule derives `SubscriptionRootState` from
  `SubscriptionAccess` and `hasValidIdentity`; test the four combinations
  without rendering SwiftUI.

- [ ] **Step 1: Add root-state and UI-launch RED coverage**

  Add table-driven tests:

  ```swift
  @Test(arguments: [
      (SubscriptionAccess.loading, false, SubscriptionRootState.loading),
      (.readOnly, false, .subscriptionWelcome),
      (.full, false, .ownerSetup),
      (.readOnly, true, .app(readOnly: true)),
      (.full, true, .app(readOnly: false)),
  ])
  func rootState(access: SubscriptionAccess, hasIdentity: Bool, expected: SubscriptionRootState) {
      #expect(SubscriptionRootRules.state(access: access, hasIdentity: hasIdentity) == expected)
  }
  ```

  Add UI launch environment key `FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS`; all
  existing UI tests default to full access, while new tests explicitly request
  read only.

- [ ] **Step 2: Run root-state tests and verify RED**

  Run only `SubscriptionRootStateTests`; expect missing symbols.

- [ ] **Step 3: Compose subscription dependency and root state**

  Add `SubscriptionAccessModel` to `AppDependencies`, inject it with
  `.environment`, and start it from `RootView`. Previews use a deterministic
  full-access source. UI tests use the launch override and never contact the
  App Store.

  Keep photograph reconciliation independent so it continues protecting
  existing files in read-only mode.

- [ ] **Step 4: Build the native store surfaces**

  `SubscriptionView` uses:

  ```swift
  SubscriptionStoreView(productIDs: SubscriptionProduct.orderedIdentifiers) {
      VStack(alignment: .leading, spacing: 12) {
          Text("FarrierFlow Pro").font(.title2.bold())
          Text("Run appointments, horse history, work, photos, invoices, and follow-up in one field-ready workflow.")
          Text("Your records stay on this iPhone. Cancel anytime; existing records remain available read only.")
              .font(.footnote)
              .foregroundStyle(.secondary)
      }
  }
  .subscriptionStoreControlStyle(.picker)
  .storeButton(.visible, for: .restorePurchases)
  ```

  Use StoreKit's automatic policy destinations from App Store Connect. Add a
  native Manage Subscription button using `manageSubscriptionsSheet` when the
  screen is reached from an existing installation. Do not hard-code prices in
  the view.

- [ ] **Step 5: Add navigation and one read-only notice**

  Add `Subscription` to Clients > More. Insert
  `SubscriptionReadOnlyNotice` once near the top of Today's loaded `List` when
  access is read only. The notice says existing records remain available and
  opens the subscription store. Do not repeat it on every record detail.

- [ ] **Step 6: Run focused unit and UI GREEN**

  Run `SubscriptionRootStateTests`, `OwnerSetupReadinessModelTests`, and the two
  new UI selectors: no-profile/read-only shows Subscription; seeded
  profile/read-only shows Today plus the notice and can open Subscription from
  Clients > More.

- [ ] **Step 7: Audit and commit Unit 3**

  ```bash
  git commit -m "feat(subscription): add native purchase flow"
  ```

---

## Task 4 — Unit 4 — Read-Only Mutation Boundary

**Goal:** Remove normal production mutation in read-only mode while preserving
all viewing and PDF generation/sharing from existing Invoices.

**Files:**

- Modify the mutation surfaces below; do not modify unrelated projection-only
  views or SwiftData schema files.

| Feature | Files | Read-only behavior |
| --- | --- | --- |
| Today | `FarrierFlow/Features/Today/Views/TodayView.swift` | Hide Schedule, Add Client, Create Invoice, and next-Appointment mutation entry; replace Resume Visit with View Visit; keep record navigation and invoice review |
| Schedule | `FarrierFlow/Features/Schedule/Views/ScheduleView.swift`, `AppointmentDetailView.swift`, `AppointmentEditorView.swift`, `NextAppointmentAssistantView.swift` | Hide add/edit/delete/start and Continue-to-save; present an in-progress Visit as read-only detail instead of its editor; keep Appointment and all Visit viewing |
| Clients | `FarrierFlow/Features/Clients/Views/ClientListView.swift`, `ClientDetailView.swift`, `ClientEditorView.swift` | Hide add/edit/delete/Create Invoice; keep Client/Horse/Invoice navigation |
| Service Locations | `FarrierFlow/Features/Barns/Views/BarnListView.swift`, `BarnDetailView.swift`, `BarnEditorView.swift`, `ExistingHorsePickerView.swift` | Hide add/edit/delete/relocate; keep lists and details |
| Horses | `FarrierFlow/Features/Horses/Views/HorseDetailView.swift`, `HorseEditorView.swift` | Hide add/edit/delete/relocate; keep detail and history |
| Services | `FarrierFlow/Features/Services/Views/ServiceListView.swift`, `ServiceDetailView.swift`, `ServiceEditorView.swift` | Hide add/edit/archive/reactivate/delete; keep catalog and historical detail |
| Visits | `FarrierFlow/Features/Visits/Views/VisitDetailView.swift`, `VisitEditorView.swift`, `AddServicePickerView.swift`, `WorkItemEditorView.swift` | Hide start/resume/edit/correct, save/complete/discard, and WorkItem mutation; an open editor disables its form and suppresses background save |
| Photographs | `FarrierFlow/Features/Photographs/Views/PhotographCollectionView.swift` | Keep viewing; hide camera/import/delete |
| Invoices | `FarrierFlow/Features/Invoices/Views/InvoiceCreationView.swift`, `InvoiceDetailView.swift` | Block Invoice generation, mark-paid, and delete; keep PDF generation and Share PDF for existing Invoices exactly available |
| Owner profile | `FarrierFlow/Features/BusinessProfile/Views/BusinessProfileEditorView.swift` | Existing profile values remain visible in a disabled form with no Save; identity mode is reachable only with full access |

- Test: `FarrierFlowUITests/SubscriptionReadOnlyUITests.swift`
- Test: `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift` only if a
  small injected access guard is required for background saving.

**Interfaces:**

Every listed view reads:

```swift
@Environment(SubscriptionAccessModel.self) private var subscription
```

Mutation entry points use `subscription.allowsMutations`. Navigation, Retry,
Cancel, Done, photograph opening, and Invoice PDF sharing never use that gate.

- [ ] **Step 1: Write end-to-end read-only RED tests**

  Seed a representative existing graph and launch with read-only access. Assert:

  - Today and record details remain navigable.
  - Add/Edit/Delete/Start/Resume/Create Invoice/Mark Paid controls do not exist.
  - Photograph thumbnail opens and has no Delete action.
  - Invoice `Share PDF` generates a temporary PDF from the existing snapshots
    and opens the native share flow.
  - Relaunch fetch counts and representative scalar values are unchanged.

  Add one full-access control test proving the same mutation controls are still
  present under the deterministic full entitlement.

- [ ] **Step 2: Run the read-only selectors and verify RED**

  Expected: current mutation controls remain visible.

- [ ] **Step 3: Gate list, detail, and editor actions feature by feature**

  Prefer conditional omission for entry points:

  ```swift
  if subscription.allowsMutations {
      Button("Add Client", systemImage: "plus") { showsEditor = true }
  }
  ```

  For an already-open editor, retain Cancel/Done while disabling content and
  save:

  ```swift
  form.disabled(!subscription.allowsMutations)

  Button("Save", action: save)
      .disabled(!subscription.allowsMutations || !model.canSave)

  private func save() {
      guard subscription.allowsMutations else { return }
      // Existing save boundary remains unchanged.
  }
  ```

  `VisitEditorView` must also guard its scene-phase background save before
  calling `saveProgressForBackground()`.

  For existing in-progress Visit records, use the already-available read-only
  `VisitDetailView` instead of making the record unreachable. Today adds a
  `.visit(PersistentIdentifier)` navigation route using
  `TodayVisitSummary.id`. Appointment Detail sets
  `model.visitPresentation = .detail(visit.persistentModelID)` when read only,
  even if the Visit is incomplete. Full access retains the existing Resume
  editor behavior.

- [ ] **Step 4: Prove existing-Invoice PDF output is not paywalled**

  Run `InvoicePDFShareModelTests` and the read-only Invoice UI selector. The
  share action must remain enabled and its preparation may create only the
  ordinary temporary PDF from persisted Invoice snapshots; it changes no
  SwiftData business record.

- [ ] **Step 5: Run affected feature suites**

  Run the existing Schedule, Client, Barn, Horse, Service, Visit, Photograph,
  BusinessProfile, Invoice, Today, and next-Appointment model suites in one
  serial iOS 26 command, plus the read-only UI suite. Existing tests run with
  full access and must remain unchanged in behavior.

- [ ] **Step 6: Perform a mutation-minded source audit**

  Use targeted `rg` searches for `context.save`, `context.insert`,
  `context.delete`, `DomainGraphValidator.save`, Photograph add/delete, Visit
  save/complete/discard, Invoice generate/status/delete, and editor Save
  buttons. Map every production user-triggered mutation back to a gated surface.
  Maintenance-only Photograph reconciliation and Invoice PDF temporary-file
  creation are documented exceptions.

- [ ] **Step 7: Audit and commit Unit 4**

  ```bash
  git commit -m "feat(subscription): preserve read-only records"
  ```

---

## Task 5 — Unit 5 — StoreKit Configuration and Subscription Acceptance

**Goal:** Make the approved products reproducible in Xcode and App Store
Connect, then prove trial, grace, expiration, restore, and renewal behavior.

**Files:**

- Create: `FarrierFlow/Resources/FarrierFlow.storekit`
- Create or modify:
  `FarrierFlow.xcodeproj/xcshareddata/xcschemes/FarrierFlow.xcscheme`
- Create: `docs/release/storekit-configuration.md`
- Modify: `FarrierFlow/Resources/Localizable.xcstrings`
- Test: `FarrierFlowTests/Features/Subscription/SubscriptionProductTests.swift`

**Interfaces:**

The configuration contains one group `FarrierFlow Pro`, monthly and yearly
products with the exact Unit 2 identifiers, approved US prices, 14-day free
trials, no Family Sharing, and no additional offers.

- [ ] **Step 1: Add product-contract tests**

  Assert exact identifier set and yearly-first display order. Parse the checked
  in `.storekit` file as JSON in the test target and assert both identifiers,
  monthly/yearly durations, prices, and introductory offers are present. This
  catches drift between code and StoreKit testing configuration.

- [ ] **Step 2: Verify RED against the absent configuration**

  Run `SubscriptionProductTests`; expect the resource/configuration assertion
  to fail.

- [ ] **Step 3: Create StoreKit Configuration in Xcode**

  Use Xcode's StoreKit Configuration editor so the file uses the installed
  schema. Set:

  - Group reference name: `FarrierFlow Pro`
  - Localized group name: `FarrierFlow Pro`
  - Monthly reference/display name: `FarrierFlow Monthly`
  - Monthly duration/price: 1 month / 14.99 USD
  - Yearly reference/display name: `FarrierFlow Yearly`
  - Yearly duration/price: 1 year / 119.99 USD
  - Introductory offer on both: free / 14 days
  - Family Sharing: off

  Share the FarrierFlow scheme and select `FarrierFlow.storekit` for Run.
  Inspect the generated scheme and configuration diff; do not hand-edit unknown
  StoreKit JSON keys.

- [ ] **Step 4: Mirror configuration in App Store Connect**

  This step requires explicit authorization for commercial portal changes.
  Create the same group/products/localizations, select equivalent storefront
  price points, add the 14-day offers, and enable 16-day billing grace for **All
  Renewals** in production and sandbox. Record App Store Connect reference
  identifiers and screenshots in `docs/release/storekit-configuration.md`;
  never record account credentials.

- [ ] **Step 5: Execute StoreKit state acceptance**

  With Xcode's transaction manager, verify fresh/no purchase, monthly trial,
  yearly trial, active renewal, cancel while paid through, grace, billing retry
  outside grace, expiration, revocation/refund, restore, and resubscribe.
  Capture the observed app access and confirm source SwiftData fetch counts and
  Photograph files remain unchanged across every access-only transition.

- [ ] **Step 6: Run focused GREEN and commit Unit 5**

  ```bash
  git commit -m "test(subscription): configure launch products"
  ```

---

## Task 6 — Unit 6 — Privacy, Icon, and App Store Release Materials

**Goal:** Remove the known binary and listing blockers without adding product
scope.

**Files:**

- Create: `FarrierFlow/PrivacyInfo.xcprivacy`
- Create:
  `FarrierFlow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- Create:
  `FarrierFlow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-dark.png`
- Create:
  `FarrierFlow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-tinted.png`
- Modify:
  `FarrierFlow/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `docs/release/privacy-policy.md`
- Create: `docs/release/support.md`
- Create: `docs/release/app-store-metadata.md`
- Create: `docs/release/submission-checklist.md`
- Modify: `FarrierFlow.xcodeproj/project.pbxproj` only if the synchronized group
  does not automatically include the privacy manifest.

**Interfaces:**

The privacy manifest content is exact:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>E174.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 1: Add and validate the privacy manifest**

  Add the exact manifest, confirm it appears in the built app bundle, and run:

  ```bash
  plutil -lint FarrierFlow/PrivacyInfo.xcprivacy
  ```

  Re-audit production code for all Apple required-reason API categories before
  retaining the Data Not Collected declaration.

- [ ] **Step 2: Produce and review the three App Icon variants**

  Use the image-generation skill for candidate production assets. Direction:
  flat Survey Ink background, one high-contrast forward workline mark, no text,
  no horseshoe, no horse illustration, no western styling, no gradient, no
  transparency. Review at 1024, 180, 120, 60, and 40 points in Light, Dark, and
  tinted appearances. Select one family before placing files in the asset set.

- [ ] **Step 3: Wire and validate icon assets**

  Add filename keys for all three universal 1024 entries in `Contents.json`.
  Verify each PNG is 1024×1024, RGB/RGBA without alpha, and visible in an
  installed simulator build and Xcode asset validation.

- [ ] **Step 4: Write truthful public release content**

  The privacy source states: local business records and photographs stay on the
  device; FarrierFlow adds no account, analytics, advertising, tracking, or
  developer server; Apple processes App Store subscriptions; deletion follows
  the app's explicit record rules; users can contact support for product help.

  The support source contains installation requirements, purchase/restore and
  read-only explanations, local-data/backup warning, camera/photo access help,
  and a real monitored support contact chosen by the owner.

  The metadata source contains exact name, subtitle, description, keywords,
  category, age-rating answers, promotional text, review notes, subscription
  explanation, privacy answers, and screenshot shot list. It claims only
  implemented features and contains no testimonials or invented customers. It
  links Apple's Standard EULA at
  `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` and the
  owner-controlled Privacy Policy.

- [ ] **Step 5: Publish public HTTPS pages and verify portal prerequisites**

  Hosting and commercial account changes are external-state actions and require
  explicit authorization. Publish the approved privacy/support content at
  owner-controlled HTTPS URLs, verify them without authentication on phone and
  desktop, then enter them in App Store Connect. Verify Paid Apps Agreement,
  tax, banking, app record, bundle identifier, version 1.0, and Data Not
  Collected answers. Do not invent or commit a domain.

- [ ] **Step 6: Capture truthful screenshots**

  Use deterministic development fixtures clearly representing the product,
  not fake customer evidence. Capture the required current iPhone sizes from
  the release candidate after Subscription and read-only UI are final. Verify
  no debug labels, test data disclaimers, clipped Dynamic Type, or private real
  customer information appears.

- [ ] **Step 7: Validate resources and commit Unit 6**

  ```bash
  xcrun xcstringstool compile --dry-run \
    --output-directory "$(mktemp -d)" \
    FarrierFlow/Resources/Localizable.xcstrings
  git diff --check
  git commit -m "chore(release): add App Store materials"
  ```

---

## Task 7 — Unit 7 — Release Candidate, TestFlight, and Submission

**Goal:** Prove the paid owner flow once at release scope, upload one clean
candidate, and submit version 1.0 with the subscriptions.

**Files:**

- Modify: `docs/release/submission-checklist.md`
- Modify: `ROADMAP.md` only after the corresponding gate actually passes.
- Modify: `FarrierFlow.xcodeproj/project.pbxproj` only for the final approved
  build number or signing/release setting.

**Interfaces:** No product interface. This unit verifies and publishes the
exact release candidate; it does not add features or opportunistic hardening.

- [ ] **Step 1: Freeze candidate scope**

  Confirm the diff from `origin/main` contains only Units 1–6 and approved
  documentation. Confirm no Export Unit 2, coordinator, backup, account,
  analytics, or unrelated feature code entered the branch. Set version 1.0 and
  an approved monotonically increasing build number.

- [ ] **Step 2: Run final serial automated gates once**

  After all code review fixes are complete, run in order:

  1. Full iOS 18 unit/integration suite.
  2. Full iOS 26 unit/integration suite.
  3. Focused iOS 18 subscription and first-customer UI flows.
  4. Full iOS 26 UI suite, including active and read-only subscription flows.
  5. iOS 18 and iOS 26 `PersistentStoreReopenTests`.
  6. iOS 18 and iOS 26 builds.
  7. Privacy manifest, string catalog, asset catalog, and `git diff --check`.

  Use exact selectors with trailing `()` where required and inspect `.xcresult`
  executed counts. Do not rerun a passed full gate unless source changes.

- [ ] **Step 3: Perform physical-device acceptance**

  On one iPhone using sandbox/TestFlight:

  1. Fresh no-entitlement launch.
  2. Monthly or yearly trial purchase.
  3. Owner setup.
  4. Client → Horse → Appointment → Visit → photographs → Invoice → Paid →
     next Appointment.
  5. Relaunch and offline use.
  6. Grace then expiration/read-only transition.
  7. Existing record and photograph access plus PDF generation/sharing from an
     existing Invoice in read-only mode.
  8. Restore/resubscribe and full-access return.
  9. VoiceOver, accessibility Dynamic Type, Light/Dark Mode, Increased Contrast,
     and Reduce Motion on the subscription and core mutation boundary.

- [ ] **Step 4: Archive and validate**

  Create one Release archive with automatic signing after explicit signing
  authorization. Validate it in Organizer. Resolve only submission blockers;
  do not expand features during archive cleanup.

- [ ] **Step 5: Upload TestFlight candidate**

  Upload only after explicit authorization. Verify processing, export
  compliance, privacy manifest, subscription products, and internal testing.
  Repeat only the focused physical smoke test on the exact processed build.

- [ ] **Step 6: Submit version 1.0 and both subscriptions**

  Confirm screenshots, metadata, URLs, privacy answers, review notes, trial and
  recurring-price disclosure, selected build, subscriptions, agreements, tax,
  and banking. The first subscriptions must be attached to version 1.0. Obtain
  explicit authorization immediately before clicking **Submit for Review**.

- [ ] **Step 7: Record final state**

  Update the checklist and roadmap with exact build, commit, TestFlight status,
  App Store Connect status, tests, residual risks, and whether submission was
  actually clicked. Do not call **Ready for Review** submitted.

  Commit documentation closure only after it is true:

  ```bash
  git commit -m "docs: record FarrierFlow 1.0 release state"
  ```

## Self-Review Checklist

- [ ] Every approved pricing, trial, grace, restore, offline, and read-only rule
  maps to a unit and test.
- [ ] Every production user-triggered business mutation maps to Unit 4's audit.
- [ ] PDF generation and sharing from existing Invoices remain available in
  read-only mode.
- [ ] No StoreKit state enters SwiftData or Photograph storage.
- [ ] The stale-Appointment fix is adapted to `origin/main` without importing
  the Export coordinator.
- [ ] App Icon, privacy manifest, public policies, agreements, product setup,
  screenshots, TestFlight, and submission each have an explicit gate.
- [ ] No placeholder screen, product, URL, server, account, dependency, Export
  unit, or backup work is included.
- [ ] No `TODO`, `TBD`, `FIXME`, or ambiguous “handle errors” step remains.
