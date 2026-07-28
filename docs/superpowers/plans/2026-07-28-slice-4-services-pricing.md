# Slice 4 — Services and Pricing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `superpowers:test-driven-development` for every behavior change and
> `superpowers:verification-before-completion` before reporting the slice
> complete. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a migration-safe Service catalog, optional Horse default Service, and VisitHorse-owned priced WorkItems without changing the meaning of pre-Slice-4 history.

**Architecture:** Preserve the existing `SwiftUI View → @MainActor @Observable feature model → focused rule/use case → SwiftData` direction. V4 is a complete ten-model schema with one additive V3-to-V4 lightweight stage; its immutable `Visit.workItemPolicyVersion` distinguishes legacy structured-work absence from Slice 4 completion requirements. Money is represented only by checked `Int64` USD minor units, while in-memory Visit drafts apply WorkItem edits atomically at the existing explicit save boundaries.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, Observation, SwiftData versioned schemas, Foundation currency formatting, OSLog, Swift Testing/XCTest, XCTest UI testing, iOS 18.0 minimum, latest stable iOS 26 SDK.

## Global Constraints

- Implement only the approved Slice 4 design in `docs/superpowers/specs/2026-07-28-slice-4-services-pricing-design.md`.
- Preserve V1, V2, and V3 as frozen schema snapshots. Preserve production configuration name, URL, and store identity.
- V4 contains exactly Client, Barn, Horse, Appointment, AppointmentHorse, Visit, VisitHorse, Photograph, Service, and WorkItem.
- `Visit.workItemPolicyVersion` accepts only `0` (legacy) and `1` (Slice 4); migration assigns `0`, and `VisitStartUseCase` explicitly assigns `1`.
- Store amounts only as nonnegative `Int64` minor units and an explicit `USD` code. Do not parse, total, store, compare, or convert money through `Double` or `Float`.
- Use the approved exact `en-US` price grammar for entry and localized Foundation USD formatting for display. Show zero as `Complimentary`.
- A WorkItem has exactly one Service and one VisitHorse; one `(VisitHorse, Service)` pair may occur once only. Enforce it in draft editing, use cases, full-graph validation, and reopening validation.
- WorkItem snapshots remain authoritative for completed history. Catalog edits, Horse-default edits, migration, and relocation never rewrite them.
- WorkItems are owned only by `VisitHorse`; add no quantity, unit price, Visit-level charge, tax, discount, adjustment, invoice, payment, or future-charge scaffold.
- Use visible **Hoof Photos** copy only. Do not rename Swift/Persistence `Photograph` types, schema entities, filenames, or identifiers.
- Preserve existing Visit start, save-progress, completion, correction, discard, photograph, relocation, and appointment-lock invariants.
- Use native `List`, `Form`, `Picker`, `Menu`, `sheet`, `alert`, and `confirmationDialog`; add no tab, custom navigation, custom controls, or simulated Liquid Glass.
- Put every user-facing string in `FarrierFlow/Resources/Localizable.xcstrings` and follow `docs/WRITING_STYLE.md` (`Service`, `Performed Service`, `Photo`, no raw USD/minor-unit terminology).
- All verification is serial. Before each command, confirm no `xcodebuild`, `xctest`, or simulator test runner is alive; use one existing simulator destination, `-parallel-testing-enabled NO`, and `-maximum-parallel-testing-workers 1`. Stop if memory pressure or swap is rising.
- Keep commits small and reviewable; inspect `git diff --check` and the exact staged diff before each commit. Do not stage unrelated existing changes.
- Do not create an invoice/payment/Visit-charge route, model, field, protocol, directory, or placeholder.

## Execution Configuration

Use **Terra High** for schema/migration, relationship/delete-rule policy, money, full-graph validation, and persistence transactions. Use **Terra Medium** for UI, accessibility, localization, and documentation. Escalate to **Sol High** only when a reproducible iOS 18 migration failure, SwiftData relationship/delete-rule incompatibility, transaction rollback/data-loss risk, or unresolved policy/spec contradiction remains after focused evidence.

Reuse the repository-established serial simulator destinations without booting
or cloning another simulator:

```bash
IOS18_DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0'
IOS26_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
pgrep -fl 'xcodebuild|xctest|XCTRunner'

xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
  -destination "$IOS18_DESTINATION" \
  -parallel-testing-enabled NO -maximum-parallel-testing-workers 1
```

If either named destination is no longer installed, stop before Task 1 and
select one existing device on the same required runtime; do not boot or clone
another simulator. If the preflight lists a surviving build/test process or
memory pressure is elevated, stop and clear that resource condition before
running the next command.

---

### Task 1: V4 schema and iOS 18 migration hard gate

**Recommended configuration:** Terra High. Escalate to Sol High only for a reproducible iOS 18 additive-migration incompatibility or data-preservation risk.

**Files:**

- Create: `FarrierFlow/Core/Persistence/Schema/V4/FarrierFlowSchemaV4.swift`, `V4Client.swift`, `V4Barn.swift`, `V4Horse.swift`, `V4Appointment.swift`, `V4AppointmentHorse.swift`, `V4Visit.swift`, `V4VisitHorse.swift`, `V4Photograph.swift`, `V4Service.swift`, `V4WorkItem.swift`
- Create: `FarrierFlowTests/Support/V3StoreFixture.swift`
- Modify: `FarrierFlow/Core/Persistence/Schema/CurrentSchema.swift`, `FarrierFlow/Core/Persistence/Migrations/FarrierFlowMigrationPlan.swift`, `FarrierFlow/Core/Persistence/ModelContainerFactory.swift`, `FarrierFlowTests/Support/V1StoreFixture.swift`, `FarrierFlowTests/Support/V2StoreFixture.swift`, `FarrierFlowTests/Core/Persistence/SchemaContractTests.swift`, `FarrierFlowTests/Core/Persistence/SchemaMigrationTests.swift`, `FarrierFlowTests/Core/Persistence/ModelContainerFactoryTests.swift`, `FarrierFlowTests/Core/Persistence/SwiftDataRelationshipInsertionTests.swift`, `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`
- Do not modify before the iOS 18 migration gate passes: money, Services, Horses, Visits UI, Visit use cases, or app documentation.

**Interfaces:**

- Produces `nonisolated enum FarrierFlowSchemaV4: VersionedSchema` with `Schema.Version(4, 0, 0)` and exactly ten `models`.
- Produces `FarrierFlowSchemaV4.Visit.workItemPolicyVersion: Int`,
  `Visit.legacyWorkItemPolicyVersion == 0`, and
  `Visit.slice4WorkItemPolicyVersion == 1`; the initializer default is `0`
  only for additive migration compatibility, while controlled new-Visit
  creation passes `Visit.slice4WorkItemPolicyVersion` explicitly.
- Produces `FarrierFlowSchemaV4.Horse.defaultService: Service?`, `FarrierFlowSchemaV4.VisitHorse.workItems: [WorkItem]`, `FarrierFlowSchemaV4.Service`, and `FarrierFlowSchemaV4.WorkItem` with the approved inverse/delete-rule matrix.
- Produces `CurrentSchema` aliases for `Service` and `WorkItem`, and `FarrierFlowMigrationPlan` stages `V1→V2`, `V2→V3`, `V3→V4`, with every prior stage byte-for-byte behaviorally unchanged.
- Consumed later by `DomainGraphValidator`, `VisitStartUseCase`, Service/Horse/Visit feature models, all containers, and reopening tests.

- [ ] **Step 1: Write the failing V4 contract and migration tests before production V4 code.**

  Add assertions that V1–V3 remain frozen; V4 contains exactly ten models; `Service` has normalized-name/`Int64`/`USD`/archive fields; `WorkItem` is VisitHorse-owned; `Horse.defaultService` is optional; and delete rules match the approved table. Create `V3StoreFixture` with a complete Visit/VisitHorse/Photograph graph. Add direct V3→V4, chained V2→V3→V4, and non-vacuous staged V1→V2→V3→V4 tests. The V1 chain must first create a V1 graph, migrate the same store to V2, insert a Visit/VisitHorse only after V2 supports it, migrate that same store to V3, then V4 and prove the exact persisted Visit reaches V4 with `workItemPolicyVersion == 0`, empty `workItems`, a nil Horse default, preserved Photograph metadata/file state, and no fabricated Service/snapshot/amount/currency/default.

  ```swift
  #expect(migratedVisit.workItemPolicyVersion == 0)
  #expect(migratedVisitHorse.workItems.isEmpty)
  #expect(migratedHorse.defaultService == nil)
  #expect(try context.fetch(FetchDescriptor<Service>()).isEmpty)
  ```

- [ ] **Step 2: Run the new migration tests on the existing iOS 18 simulator and confirm they fail for missing V4 symbols/contract.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/SchemaContractTests \
    -only-testing:FarrierFlowTests/SchemaMigrationTests
  ```

  Expected: compilation/test failure because V4, policy value, or the V3→V4 migration stage does not yet satisfy the asserted contract.

- [ ] **Step 3: Implement the complete V4 snapshot and append only the additive V3→V4 lightweight migration stage.**

  Copy each V3 model into its V4 namespace unchanged unless the approved V4 additions require a change. Add `Visit.workItemPolicyVersion` with migration-safe default `0`; `Horse.defaultService`; `VisitHorse.workItems` cascade; `Service.horsesUsingAsDefault` and `Service.workItems` deny inverses; and optional storage/domain-required `WorkItem.service`/`visitHorse`. Point aliases and all container configurations to V4. Do not change V1–V3 model source, recreate stores, or fabricate records in migration code.

  ```swift
  @Relationship(deleteRule: .cascade, inverse: \WorkItem.visitHorse)
  var workItems: [WorkItem] = []

  @Relationship(deleteRule: .deny, inverse: \WorkItem.service)
  var workItems: [WorkItem] = []
  ```

- [ ] **Step 4: Make migration/reopening fixtures prove production-store identity and V4 persistence.**

  Release the old `ModelContainer`, reopen the exact same URL using V4, prove all prior inverse relationships and file-backed Photograph metadata remain available, then create a valid V4 graph and reopen it. Assert existing Visits stay policy `0` and no Service/WorkItem data was invented.

- [ ] **Step 5: Run the iOS 18 hard migration gate.**

  Run the Step 2 command again.

  Expected: PASS for direct V3→V4 and both chained migrations, with every existing Visit at policy `0`, no fabricated WorkItems, and no replacement empty store.

  **Hard stop:** If this gate fails, stop Slice 4 implementation immediately. Do not start Task 2 or modify source beyond migration-proof test/schema/migration changes. Report the exact iOS 18 failure and request schema review; never recreate, replace, or silently empty the store.

- [ ] **Step 6: Commit the isolated migration gate after review.**

  ```bash
  git add -- FarrierFlow/Core/Persistence/Schema/V4 \
    FarrierFlow/Core/Persistence/Schema/CurrentSchema.swift \
    FarrierFlow/Core/Persistence/Migrations/FarrierFlowMigrationPlan.swift \
    FarrierFlow/Core/Persistence/ModelContainerFactory.swift \
    FarrierFlowTests/Support/V1StoreFixture.swift \
    FarrierFlowTests/Support/V2StoreFixture.swift \
    FarrierFlowTests/Support/V3StoreFixture.swift \
    FarrierFlowTests/Core/Persistence/SchemaContractTests.swift \
    FarrierFlowTests/Core/Persistence/SchemaMigrationTests.swift \
    FarrierFlowTests/Core/Persistence/ModelContainerFactoryTests.swift \
    FarrierFlowTests/Core/Persistence/SwiftDataRelationshipInsertionTests.swift \
    FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: migrate persistence schema to v4"
  ```

### Task 2: Domain validation and exact money

**Recommended configuration:** Terra High. Escalate to Sol High only for a reproducible checked-arithmetic, persisted-data safety, or domain-policy ambiguity.

**Files:**

- Create: `FarrierFlow/Core/Money/USDPriceParser.swift`, `FarrierFlow/Core/Money/MoneyFormatter.swift`, `FarrierFlow/Core/Money/CheckedMoneyTotal.swift`, `FarrierFlow/Core/Money/MoneyAvailability.swift`, `FarrierFlowTests/Core/Money/USDPriceParserTests.swift`, `FarrierFlowTests/Core/Money/CheckedMoneyTotalTests.swift`, `FarrierFlowTests/Core/Money/MoneyAvailabilityTests.swift`, `FarrierFlowTests/Core/Persistence/WorkItemDomainValidationTests.swift`
- Modify: `FarrierFlow/Core/Persistence/DomainGraphValidator.swift`, `FarrierFlow/Core/Persistence/RecordDeletionRules.swift`, `FarrierFlowTests/Core/Persistence/DomainGraphValidatorTests.swift`, `FarrierFlowTests/Core/Persistence/RecordDeletionRulesTests.swift`, `FarrierFlowTests/Support/ModelFixtures.swift`, `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`

**Interfaces:**

- Produces `USDPriceParser.parse(_ input: String) throws -> Int64` and `editableString(minorUnits:) -> String?`; it accepts only the approved whitespace-trimmed `en-US` grammar.
- Produces `MoneyFormatter.usd(minorUnits:locale:) -> String?`, with zero returning localized `Complimentary`.
- Produces `CheckedMoneyTotal.sum<S: Sequence>(_ amounts: S) throws -> Int64 where S.Element == Int64` with errors for negative input or overflow.
- Produces `nonisolated enum MoneyAvailability: Equatable { case available(Int64); case unavailable }`,
  `CheckedMoneyTotal.projectedSubtotal(_:unavailableWhenEmpty:) throws -> MoneyAvailability`,
  and `CheckedMoneyTotal.projectedTotal(_:) throws -> MoneyAvailability`.
  `projectedTotal` returns `.unavailable` when any input is unavailable and
  otherwise performs checked addition.
- Extends `DomainGraphValidator.validateAll(in:)` to validate policies, Service lifecycle/inverses, WorkItem ownership/inverses/snapshots/currency, pair uniqueness, outcome-dependent counts, and checked totals.
- Extends typed deletion preflight with Service archive/delete reasons; callers receive a specific blocked explanation before SwiftData deny protection.

- [ ] **Step 1: Write failing pure-rule tests.**

  Cover accepted `0`, `12`, `12.`, `12.5`, `12.50`, `$12.50`, `1,250.00`, surrounding whitespace, and the exact maximum cents that fit `Int64`. Reject signs, parentheses, leading decimal, malformed commas, three fractions, exponent/currency text, unsupported separators, internal whitespace, letters, and checked overflow. Cover `Complimentary`, nonzero localized USD, negative rejection, per-Horse/Visit checked total, unavailable legacy empty subtotal, unavailable propagation to Visit total, and every overflow boundary.

  ```swift
  #expect(try USDPriceParser.parse("  $1,250.50  ") == 125_050)
  #expect(throws: USDPriceParsingError.invalidFormat) {
      _ = try USDPriceParser.parse("$ 12.50")
  }
  #expect(throws: CheckedMoneyTotalError.overflow) {
      _ = try CheckedMoneyTotal.sum([Int64.max, 1])
  }
  #expect(
      try CheckedMoneyTotal.projectedSubtotal(
          [],
          unavailableWhenEmpty: true
      ) == .unavailable
  )
  ```

- [ ] **Step 2: Run focused tests and confirm expected failures.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/USDPriceParserTests \
    -only-testing:FarrierFlowTests/CheckedMoneyTotalTests \
    -only-testing:FarrierFlowTests/MoneyAvailabilityTests \
    -only-testing:FarrierFlowTests/WorkItemDomainValidationTests
  ```

  Expected: FAIL on the first missing exact-parser, unavailable-projection,
  checked-total, or policy-aware graph-validation assertion.

- [ ] **Step 3: Implement exact integer money and fail-closed V4 domain validation.**

  Validate grammar fully before conversion; remove `$`/commas; parse digits
  with checked multiplication/addition; right-pad fractional digits; never use
  `Double`/`Float`. Implement unavailable projection without treating empty
  legacy history as zero. Validate `workItemPolicyVersion` is only `0`/`1`;
  active normalized Horse defaults; Service `USD`; WorkItem service +
  VisitHorse inverses; unique pairs; no Not Serviced WorkItems; policy-1
  completed Serviced minimum; and all checked recorded subtotals/totals. The
  graph validator validates the supported current value and current graph
  invariants only; it does not claim stateless proof of historical policy
  immutability. A persisted duplicate/overflow/unknown policy logs a structural
  violation, disables unsafe mutation, and is never silently repaired or
  summed as quantity.

- [ ] **Step 4: Extend deletion/archival policy tests and implementation.**

  Implement preflight that blocks archive while `horsesUsingAsDefault` is nonempty; blocks permanent deletion when either Horse default or any in-progress/completed WorkItem reference exists; allows archive after defaults are cleared while retaining history; and lets deleting an owned WorkItem preserve Service and VisitHorse. Keep all V1–V3 deletion rules unchanged.

- [ ] **Step 5: Run focused pass and commit.**

  Rerun the Step 2 command.

  Expected: PASS; parser has no floating-point path, totals never wrap, and invalid persisted V4 data fails closed.

  ```bash
  git add -- FarrierFlow/Core/Money FarrierFlow/Core/Persistence/DomainGraphValidator.swift \
    FarrierFlow/Core/Persistence/RecordDeletionRules.swift \
    FarrierFlowTests/Core/Money FarrierFlowTests/Core/Persistence/WorkItemDomainValidationTests.swift \
    FarrierFlowTests/Core/Persistence/DomainGraphValidatorTests.swift \
    FarrierFlowTests/Core/Persistence/RecordDeletionRulesTests.swift \
    FarrierFlowTests/Support/ModelFixtures.swift FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: validate service work and usd amounts"
  ```

### Task 3: Service catalog

**Recommended configuration:** Terra Medium for list/detail/editor/accessibility/localization; Terra High for archive/delete lifecycle and Service persistence. Escalate to Sol High only if lifecycle rules cannot be made transaction-safe.

**Files:**

- Create: `FarrierFlow/Features/Services/Models/ServiceDraft.swift`, `FarrierFlow/Features/Services/Models/ServiceChoice.swift`, `FarrierFlow/Features/Services/ServiceRules.swift`, `FarrierFlow/Features/Services/ServiceListModel.swift`, `FarrierFlow/Features/Services/ServiceDetailModel.swift`, `FarrierFlow/Features/Services/ServiceEditorModel.swift`, `FarrierFlow/Features/Services/ServiceRoutes.swift`, `FarrierFlow/Features/Services/Components/ServiceRow.swift`, `FarrierFlow/Features/Services/Views/ServiceListView.swift`, `FarrierFlow/Features/Services/Views/ServiceDetailView.swift`, `FarrierFlow/Features/Services/Views/ServiceEditorView.swift`, `FarrierFlowTests/Features/Services/ServiceRulesTests.swift`, `FarrierFlowTests/Features/Services/ServiceEditorModelTests.swift`, `FarrierFlowTests/Features/Services/ServiceDetailModelTests.swift`
- Modify: `FarrierFlow/Features/Clients/Views/ClientListView.swift`, `FarrierFlow/Resources/Localizable.xcstrings`

**Interfaces:**

- Produces `ServiceDraft(name: String, priceInput: String)`,
  `ServiceValues(name:defaultAmountMinorUnits:currencyCode:)`, and
  `ServiceChoice(id:name:defaultAmountMinorUnits:currencyCode:)`.
- Produces `ServiceRules.validated(_:) throws -> ServiceValues`,
  `ServiceRules.activeChoices(_:locale:) -> [ServiceChoice]`, and
  `ServiceRules.sorted(_:locale:) -> [Service]` using
  active/archived/name/amount/persistent-ID ordering.
- Produces `ServiceListLoadState { loading, loaded, failed }`,
  `ServiceListModel.load(in:locale:)`, `ServiceEditorModel.save(in:)`, and
  `ServiceDetailModel.archive(in:)`, `reactivate(in:)`, and `delete(in:)`.
- Produces `enum ServiceRoute: Hashable { case list; case detail(PersistentIdentifier) }`;
  route values carry identifiers, not live contexts.
- Consumed by Horse default selection and Visit active eligible Service selection.

- [ ] **Step 1: Write failing catalog/lifecycle tests.**

  Prove normalized required name, zero/positive prices, duplicate-name identities, deterministic Active then Archived ordering, future-only rename/reprice, archive blocked by defaults, archive allowed with history, archived exclusion, Reactivate restoration, and permanent deletion only when both inverse collections are empty.

- [ ] **Step 2: Run focused failure tests.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ServiceRulesTests \
    -only-testing:FarrierFlowTests/ServiceEditorModelTests \
    -only-testing:FarrierFlowTests/ServiceDetailModelTests
  ```

  Expected: FAIL on incomplete catalog load states, deterministic ordering, or
  lifecycle transaction behavior.

- [ ] **Step 3: Implement Service persistence models and lifecycle actions.**

  Save only a normalized name, parsed nonnegative `Int64`, explicit `USD`, and active-at-create state. Archive/Reactivate/delete must validate and save through the complete graph boundary; archive does not clear/rewrite defaults or WorkItems; delete requires a native destructive confirmation and never cascades history.

- [ ] **Step 4: Implement native catalog surfaces and localized copy.**

  Add Services beside Service Locations in Clients’ More menu. Use a native list with Active/Archived sections; a no-catalog state with Add Service; no-active state guidance; unavailable/retry state; Service row name/price/archive announcement; Form editor with required Name/Price, US-dollars support copy, inline amount feedback, and unavailable Save. Detail shows current defaults with Horse navigation, Edit, Archive/Reactivate, and permitted permanent delete. Keep every string cataloged and each control at least 44 points.

- [ ] **Step 5: Run focused pass and commit.**

  Rerun the Step 2 command.

  Expected: PASS; catalog changes affect future selections only and history remains untouched.

  ```bash
  git add -- FarrierFlow/Features/Services FarrierFlow/Features/Clients/Views/ClientListView.swift \
    FarrierFlow/Resources/Localizable.xcstrings FarrierFlowTests/Features/Services
  git diff --cached --check
  git diff --cached
  git commit -m "feat: add service catalog"
  ```

### Task 4: Horse default Service

**Recommended configuration:** Terra High for default relationship validation/persistence; Terra Medium for Horse editor/detail UI and accessibility. Escalate to Sol High only if default inverse safety conflicts with iOS 18 relationship behavior.

**Files:**

- Create: `FarrierFlowTests/Features/Horses/HorseEditorModelTests.swift`, `FarrierFlowTests/Features/Horses/HorseDetailModelTests.swift`
- Modify: `FarrierFlow/Features/Horses/Models/HorseDraft.swift`, `FarrierFlow/Features/Horses/HorseEditorModel.swift`, `FarrierFlow/Features/Horses/HorseDetailModel.swift`, `FarrierFlow/Features/Horses/Views/HorseEditorView.swift`, `FarrierFlow/Features/Horses/Views/HorseDetailView.swift`, `FarrierFlowTests/Features/Horses/HorseDraftAndRelocationTests.swift`, `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`, `FarrierFlow/Resources/Localizable.xcstrings`

**Interfaces:**

- Extends `HorseDraft` with `defaultServiceID: PersistentIdentifier?`.
- Extends `HorseEditorModel` with `activeServiceChoices: [ServiceChoice]` and one existing atomic save path that resolves a selected active Service or nil.
- Extends `HorseDetailModel` with a display-safe `defaultService` projection (`name`, formatted amount, or Not Set) without touching Visit history.

- [ ] **Step 1: Write failing Horse-default tests.**

  Prove only active valid Services are selectable; None clears the relationship; selected identity/inverse persists and reopens; archived/missing/inverse-invalid default fails closed; changing a default does not change existing Appointments, Visits, WorkItems, timestamps, or snapshots.

- [ ] **Step 2: Run focused failure tests.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/HorseDraftAndRelocationTests \
    -only-testing:FarrierFlowTests/HorseEditorModelTests \
    -only-testing:FarrierFlowTests/HorseDetailModelTests
  ```

  Expected: FAIL on the first incomplete default-Service
  draft/load/save/detail/reopening behavior.

- [ ] **Step 3: Implement active-only default selection through the existing Horse save transaction.**

  Fetch sorted active Services into editor state, preserve selection through
  the existing nested service-location creation flow, resolve
  `defaultServiceID` immediately before save, and call
  `DomainGraphValidator.save`. A fetch failure leaves choices unavailable,
  disables Save, preserves the draft, and offers Retry; it never silently
  substitutes None. Never permit archived Services from stale UI state, and
  rollback while preserving the draft if save fails.

- [ ] **Step 4: Add native picker/detail and no-active guidance.**

  Add Default Service picker values None plus active Service name/price; no archived row. In detail, show selected default or Not Set. When no active Services exist, keep None usable and direct the farrier to Clients, More, Services. Localize and VoiceOver-announce name/amount/selection state.

- [ ] **Step 5: Run focused pass and commit.**

  Rerun the Step 2 command.

  Expected: PASS; Horse default is optional, valid, relaunch-safe, and affects only future Start Visit actions.

  ```bash
  git add -- FarrierFlow/Features/Horses FarrierFlowTests/Features/Horses \
    FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift \
    FarrierFlow/Resources/Localizable.xcstrings
  git diff --cached --check
  git diff --cached
  git commit -m "feat: support horse default services"
  ```

### Task 5: Start Visit defaults

**Recommended configuration:** Terra High. Escalate to Sol High only for an atomicity/rollback failure, policy-value migration conflict, or data-loss risk.

**Files:**

- Modify: `FarrierFlow/Features/Visits/VisitStartUseCase.swift`, `FarrierFlow/Features/Visits/VisitRules.swift`, `FarrierFlow/Core/Persistence/DomainGraphValidator.swift`, `FarrierFlowTests/Features/Visits/VisitStartUseCaseTests.swift`, `FarrierFlowTests/Features/Visits/VisitRulesTests.swift`, `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`, `FarrierFlowTests/Support/ModelFixtures.swift`

**Interfaces:**

- `VisitStartUseCase.start(appointmentID:now:in:) throws -> PersistentIdentifier`
  explicitly creates
  `Visit(..., workItemPolicyVersion: Visit.slice4WorkItemPolicyVersion)`.
- For every scheduled Horse with a nonnil active valid default, it inserts exactly one `WorkItem(serviceNameSnapshot:amountMinorUnits:currencyCode:service:visitHorse:)` in the same action/context as Visit and VisitHorse insertion.
- Emits typed errors that map invalid/missing/archived default data to a recoverable feature alert; it must not leave a partial graph.

- [ ] **Step 1: Write failing Start Visit tests.**

  Cover no-default Horse, default Service copy, one default line per eligible Horse, active-valid-only defaults, policy explicitly `1`, unique pairs, checked totals, and failing missing/archived/invalid/inverse-mismatched/overflowing defaults. Every failure must prove Appointment remains unchanged with no Visit, VisitHorse, or WorkItem persisted.

- [ ] **Step 2: Run focused failure tests.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/VisitStartUseCaseTests \
    -only-testing:FarrierFlowTests/VisitRulesTests
  ```

  Expected: FAIL because start does not yet explicitly assign policy 1 or atomically copy valid defaults.

- [ ] **Step 3: Implement the single Start Visit transaction.**

  Retain all existing Appointment/Barn/membership/snapshot validation. Before one save, create Visit policy `1`, all pending VisitHorses, then default WorkItems with copied Service identity/name/amount/`USD`; validate pairs, inverses, snapshots, totals, and full graph. On every error call the existing action-context rollback and return a failure; do not use a partial save or a best-effort fallback.

- [ ] **Step 4: Prove reopening and legacy separation.**

  Extend persistent-store coverage to show new V4 policy `1` graph reopens with default snapshots intact, while migration-created policy `0` Visits retain empty WorkItems and are never backfilled.

- [ ] **Step 5: Run focused pass and commit.**

  Rerun the Step 2 command.

  Expected: PASS; creation is atomic, newly created Visits are policy 1, and legacy history remains policy 0.

  ```bash
  git add -- FarrierFlow/Features/Visits/VisitStartUseCase.swift \
    FarrierFlow/Features/Visits/VisitRules.swift FarrierFlow/Core/Persistence/DomainGraphValidator.swift \
    FarrierFlowTests/Features/Visits/VisitStartUseCaseTests.swift \
    FarrierFlowTests/Features/Visits/VisitRulesTests.swift \
    FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift \
    FarrierFlowTests/Support/ModelFixtures.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: add default services when visits start"
  ```

### Task 6: WorkItem drafts and persistence

**Recommended configuration:** Terra High. Escalate to Sol High only for a reproducible save/correction/discard transaction rollback defect or policy-invariant conflict.

**Files:**

- Create: `FarrierFlow/Features/Visits/Models/WorkItemDraft.swift`, `FarrierFlow/Features/Visits/WorkItemRules.swift`
- Modify: `FarrierFlow/Features/Visits/Models/VisitDraft.swift`, `FarrierFlow/Features/Visits/VisitRules.swift`, `FarrierFlow/Features/Visits/VisitSaveUseCase.swift`, `FarrierFlow/Features/Visits/VisitEditorModel.swift`, `FarrierFlow/Features/Visits/VisitDiscardUseCase.swift`, `FarrierFlowTests/Features/Visits/WorkItemRulesTests.swift`, `FarrierFlowTests/Features/Visits/VisitRulesTests.swift`, `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`, `FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift`, `FarrierFlowTests/Core/Persistence/WorkItemDomainValidationTests.swift`, `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`

**Interfaces:**

- Produces `WorkItemDraft` with draft identity, optional persisted ID, Service persistent ID, immutable snapshot/currency, mutable nonnegative amount, and archived display state.
- Produces `WorkItemRules.violation(in:)`, `subtotal(for:) throws -> Int64`, `visitTotal(in:) throws -> Int64`, and deterministic `sorted(_:)` by snapshot name, amount, Service ID, WorkItem ID.
- Extends `VisitDraft` with immutable `workItemPolicyVersion: Int`; extends `VisitHorseDraft` with `workItems: [WorkItemDraft]`; neither exposes SwiftData models to views.
- `VisitRules.progressViolation(in:)`, `completionViolation(in:)`, and `correctionViolation(in:)` receive the draft policy and apply the policy-0 versus policy-1 WorkItem-count rule instead of unconditionally requiring a WorkItem for every completed Serviced Horse.
- `VisitEditorModel.eligibleServices(for:replacing:) -> [ServiceChoice]`,
  `addService(_:to:) -> Bool`, `removeWorkItem(_:from:)`,
  `replaceWorkItem(_:with:for:) -> Bool`,
  `isValidPriceInput(_:) -> Bool`, and
  `updateWorkItem(_:serviceID:priceInput:for:) -> Bool` own filtering, exact
  parsing, uniqueness, overflow checks, and draft mutation; SwiftUI views never
  call `USDPriceParser` directly.
- `VisitSaveUseCase.loadDraft`, `saveProgress`, `complete`, and `saveCorrection` apply insert/remove/replacement/override/outcome/note changes as one transaction; `VisitDiscardUseCase` relies on existing VisitHorse cascade and does not add file coordination.
- `VisitImmutableState` captures and compares `workItemPolicyVersion` together
  with existing relationships, timestamps, snapshots, and membership so every
  completed correction preserves policy.

- [ ] **Step 1: Write failing draft, policy, and transaction tests.**

  Cover Add exclusion, replace no-op, duplicate rejection, same Service on
  distinct VisitHorses, Pending retention under both policies, in-progress
  Serviced temporary emptiness, Not Serviced with WorkItems rejection under
  both policies, policy-0 completion with zero lines, policy-1 completion
  requiring a line, unknown policy failure, policy-0 correction retaining `0`,
  policy-1 correction retaining `1`, archived existing-line correction,
  archived exclusion from new/replacement selection, overflow preservation, and
  deterministic reloading/reopening ordering.

- [ ] **Step 2: Run focused failure tests.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/WorkItemRulesTests \
    -only-testing:FarrierFlowTests/VisitRulesTests \
    -only-testing:FarrierFlowTests/VisitEditorModelTests \
    -only-testing:FarrierFlowTests/WorkItemDomainValidationTests
  ```

  Expected: FAIL on policy-aware draft validation, atomic persistence, or
  correction/discard behavior that the partial implementation does not yet
  satisfy.

- [ ] **Step 3: Implement detached drafts and pure validation.**

  Move `ServiceChoice` consumption to the Task 3 Services model. Load the
  immutable persisted policy into `VisitDraft` alongside every WorkItem
  identity/snapshot/archive state, order deterministically, and use active
  Services filtered by already-represented IDs for Add/Replace. Reject unknown
  policy before exposing unsafe actions. Use only checked totals. Draft edits
  must keep the previous draft unchanged when an attempted
  add/replacement/override overflows or violates uniqueness.

- [ ] **Step 4: Apply all Visit metadata mutations atomically.**

  In one action context, remove deleted WorkItems; represent replacement as delete-old/insert-new (never mutate Service/snapshot in place); permit amount-only edits on existing lines; apply outcomes/notes; validate full graph; save once. On failure rollback context, retain every draft Service choice/override/note, report no success, and keep Visit state unchanged. Save Progress permits Pending and serviced-empty drafts; completion/correction enforce immutable policy-specific rules.

- [ ] **Step 5: Integrate outcome cleanup and discard correctness.**

  Pending/Serviced → Not Serviced requires one confirmation when either WorkItems or Work Notes exists; confirm clears both and all lines, cancel preserves all. Serviced → Pending retains WorkItems but applies existing Work Notes rule. In-progress discard retains existing photo-aware file transaction and deletion cascade removes WorkItems only, never Services or photo records outside the Visit.

- [ ] **Step 6: Run focused pass and commit.**

  Rerun the Step 2 command, then run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests \
    -only-testing:FarrierFlowTests/VisitDetailModelTests
  ```

  Expected: PASS; save/progress/completion/correction/discard preserve drafts/history exactly and reopen safely.

  ```bash
  git add -- FarrierFlow/Features/Visits/Models/WorkItemDraft.swift \
    FarrierFlow/Features/Visits/WorkItemRules.swift FarrierFlow/Features/Visits/Models/VisitDraft.swift \
    FarrierFlow/Features/Visits/VisitRules.swift FarrierFlow/Features/Visits/VisitSaveUseCase.swift \
    FarrierFlow/Features/Visits/VisitEditorModel.swift FarrierFlow/Features/Visits/VisitDiscardUseCase.swift \
    FarrierFlowTests/Features/Visits FarrierFlowTests/Core/Persistence/WorkItemDomainValidationTests.swift \
    FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: persist visit work items"
  ```

### Task 7: Visit Detail and Horse History

**Recommended configuration:** Terra Medium for native UI/accessibility/localization; Terra High for historical projection/ordering and unavailable-total correctness. Escalate to Sol High only for a reproducible historical-integrity or policy-display contradiction.

**Files:**

- Modify: `FarrierFlow/Features/Visits/VisitDetailModel.swift`, `FarrierFlow/Features/Visits/Views/VisitDetailView.swift`, `FarrierFlow/Features/Visits/Views/VisitEditorView.swift`, `FarrierFlow/Features/Visits/Components/VisitHorseOutcomeRow.swift`, `FarrierFlow/Features/Visits/Components/VisitHorseResultRow.swift`, `FarrierFlow/Features/Horses/HorseHistoryRules.swift`, `FarrierFlow/Features/Horses/Models/HorseHistoryEntry.swift`, `FarrierFlow/Features/Horses/Components/HorseHistoryRow.swift`, `FarrierFlow/Features/Horses/Views/HorseDetailView.swift`, `FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift`, `FarrierFlowTests/Features/Horses/HorseHistoryRulesTests.swift`, `FarrierFlowTests/Features/Horses/HorseDetailModelTests.swift`, `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`, `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`, `FarrierFlow/Resources/Localizable.xcstrings`
- Create: `FarrierFlow/Features/Visits/Views/AddServicePickerView.swift`, `FarrierFlow/Features/Visits/Views/WorkItemEditorView.swift`

**Interfaces:**

- Consumes Task 2 `MoneyAvailability`. `VisitHorseResult.subtotal` and
  `VisitDetail.total` use `MoneyAvailability`, replacing the current
  nonoptional `subtotalMinorUnits`/`totalMinorUnits` fields that would
  misrepresent unknown legacy history as zero.
- Extends `HorseHistoryEntry` with `workItemCount: Int?` and `subtotal: MoneyAvailability`; legacy policy-0 Serviced/no-line uses `nil` count and `.unavailable`, never fabricated zero/count.
- Produces `AddServicePickerView(model:visitHorseID:)` and
  `WorkItemEditorView(model:visitHorseID:workItem:)`; both invoke only the
  Task 6 `VisitEditorModel` APIs, never fetch/save SwiftData or parse money
  directly.

- [ ] **Step 1: Write failing historical-projection and accessibility tests.**

  Prove WorkItems/snapshots/order/archived state render for completed and
  correction flows and after persistent-store reopening; policy-0
  Serviced/no-line omits or marks subtotal unavailable and makes complete Visit
  total unavailable; policy-1 requires historical lines; all-zero nonempty
  subtotal reads Complimentary; snapshots survive rename/reprice/archive;
  missing Service relation keeps safe snapshot reading but disables unsafe
  navigation/mutation.

- [ ] **Step 2: Run focused failure tests.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/VisitDetailModelTests \
    -only-testing:FarrierFlowTests/HorseHistoryRulesTests \
    -only-testing:FarrierFlowTests/HorseDetailModelTests
  ```

  Expected: FAIL on legacy unavailable totals, snapshot-authoritative history,
  Service navigation safety, or model-owned WorkItem input handling.

- [ ] **Step 3: Implement Visit editor WorkItem surfaces.**

  For Pending/Serviced Horse sections show Services, Add Service, derived subtotal, Work Notes where permitted, and existing **Hoof Photos** navigation. Not Serviced shows no Add Service and no lines. Add picker has active eligible rows only and an unavailable state; editor supports exact USD amount, replacement, and removal. Use the model actions from Task 6; views do not parse money, total, fetch, or save.

- [ ] **Step 4: Implement completed Visit Detail and Horse History projections.**

  Render snapshot name/amount, archived state, horse subtotal, and checked Visit total. Allow Service navigation only when a relation resolves; snapshots remain readable otherwise. Add count/subtotal to Horse History rows without a global work-history/invoice route. Maintain established completed-Visit sort with the approved WorkItem tie-break ordering inside a horse.

- [ ] **Step 5: Apply copy/accessibility audit.**

  Catalog every string. VoiceOver announces Service name, amount, archive/selection state, unavailable/selected exclusions, `Complimentary`, and exact cleanup loss. Verify Dynamic Type wrapping, semantic colors, Light/Dark/Increase Contrast, Reduce Motion, 44-point targets, native controls, and one-handed access. Do not expose `Photograph`, `VisitHorse`, `USD`, or minor units in user copy.

- [ ] **Step 6: Run focused pass and commit.**

  Rerun the Step 2 command.

  Then run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests
  ```

  Expected: PASS; historical snapshots remain truthful and legacy absence is never represented as zero work.

  ```bash
  git add -- FarrierFlow/Features/Visits FarrierFlow/Features/Horses \
    FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift \
    FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift \
    FarrierFlowTests/Features/Horses/HorseHistoryRulesTests.swift \
    FarrierFlowTests/Features/Horses/HorseDetailModelTests.swift \
    FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift \
    FarrierFlow/Resources/Localizable.xcstrings
  git diff --cached --check
  git diff --cached
  git commit -m "feat: show performed services in visit history"
  ```

### Task 8: Integrated acceptance and documentation

**Recommended configuration:** Terra Medium for documentation/UI acceptance/accessibility; Terra High for final migration, reopening, transaction, and policy gates. Escalate to Sol High only for a remaining data-preservation, iOS 18 migration, or policy correctness failure.

**Files:**

- Modify: `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `ROADMAP.md`, `FarrierFlowUITests/VisitCompletionUITests.swift`, `FarrierFlowUITests/EditorAccessibilityUITests.swift`, `FarrierFlowUITests/BlockedMutationUITests.swift`, `FarrierFlowUITests/FormatterDisplayUITests.swift`, `FarrierFlowTests/Core/Persistence/SchemaMigrationTests.swift`, `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`

**Interfaces:**

- Documents V4 Service/WorkItem ownership, policies, exact boundaries, migration chain, and Slice 5 as deferred invoice design with no carried scaffolding.
- Produces UI acceptance coverage for the approved Services → Horse default → Start Visit → WorkItem → completion/correction/history/relaunch path.

- [ ] **Step 1: Write failing end-to-end UI and reopening cases.**

  Add `VisitCompletionUITests.testSlice4ServicesPricingFlow()` for the approved
  sequence: create active Service; set Horse default; schedule; Start Visit;
  see default line; exclude duplicate from Add; add/reprice/replace/remove;
  show Complimentary; cancel and confirm Not Serviced cleanup; complete valid
  policy-1 Visit; view totals/history; rename/reprice and preserve snapshots;
  block archive while default exists; clear/replace default then archive; read
  archived history; correct completed work; relaunch and verify
  graph/order/photos/relationships. Add direct/chained migration and
  post-migration V4 creation/reopen checks only where Tasks 1–7 have not already
  made the same assertion.

- [ ] **Step 2: Run focused failure UI test on iOS 18.**

  Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests/VisitCompletionUITests/testSlice4ServicesPricingFlow
  ```

  Expected: FAIL until the complete Slice 4 surface is wired and exposed accessibly.

- [ ] **Step 3: Update source-faithful documentation.**

  Move the architecture/data model/current behavior from Slice 3 to the implemented V4 facts only: Service lifecycle, Horse default, WorkItem snapshots/ownership/policy, checked USD rules, migration/reopening safeguards, UI routes, and explicit exclusions. Keep Slice 5 invoice/payment/Visit-charge decisions deferred; do not revise unrelated historical documentation.

- [ ] **Step 4: Run final gates serially, waiting for each process to exit before the next.**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests \
    -skip-testing:FarrierFlowTests/SchemaMigrationTests \
    -skip-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests \
    -skip-testing:FarrierFlowTests/SchemaMigrationTests \
    -skip-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests/VisitCompletionUITests \
    -only-testing:FarrierFlowUITests/EditorAccessibilityUITests \
    -only-testing:FarrierFlowUITests/BlockedMutationUITests \
    -only-testing:FarrierFlowUITests/FormatterDisplayUITests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/SchemaMigrationTests \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/SchemaMigrationTests \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION"

  xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION"

  plutil -lint FarrierFlow/Resources/Localizable.xcstrings
  git diff --check
  ```

  Expected: all serial gates pass; the broad suites skip migration/reopening so
  those resource-heavy gates run exactly once per platform in their dedicated
  commands; production store migration/reopening preserves data; both builds
  are diagnostic-free; the localization catalog is valid; and the diff has no
  whitespace errors.

- [ ] **Step 5: Perform final self-review, then commit docs/tests.**

  Verify: every spec section maps to Tasks 1–8; V1–V3 are frozen; no invoice/payment/Visit-level charge scaffolding exists; no raw currency/minor units or `Photograph` copy leaked; no `Double`/`Float` money path exists; all WorkItem paths use checks/uniqueness; policy 0 never fabricates history; policy 1 completion requires work; unavailable duplicate/overflow data has no success-shaped repair; relationship/delete rules and reopening are covered; and only intended files are staged.

  ```bash
  git add -- PRODUCT.md DESIGN.md ARCHITECTURE.md DATA_MODEL.md ROADMAP.md \
    FarrierFlowUITests/VisitCompletionUITests.swift \
    FarrierFlowUITests/EditorAccessibilityUITests.swift \
    FarrierFlowUITests/BlockedMutationUITests.swift \
    FarrierFlowUITests/FormatterDisplayUITests.swift \
    FarrierFlowTests/Core/Persistence/SchemaMigrationTests.swift \
    FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift
  git diff --cached --check
  git diff --cached
  git commit -m "docs: complete slice 4 service workflow"
  ```

## Self-Review

- [x] **Spec coverage:** Tasks 1–8 cover V4/migration first, exact money/domain policy, catalog, Horse defaults, Start Visit defaults, WorkItem drafts/transactions/discard, Visit Detail/Horse History, and acceptance/docs. Explicit exclusions are global constraints and final review checks.
- [x] **No placeholders:** Every task names concrete files, interfaces, test behaviors, expected fail/pass condition, and reviewable commit scope.
- [x] **Type consistency:** Task 1 produces the policy constants consumed by
  Tasks 2, 5, and 6; Task 2 produces `MoneyAvailability` consumed by Task 7;
  Task 3 produces `ServiceChoice` consumed by Tasks 4, 6, and 7; existing
  `VisitDraft`, `WorkItemDraft`, `USDPriceParser`, and `CheckedMoneyTotal`
  signatures remain consistent throughout.
- [x] **Migration gate:** Task 1 contains the mandatory iOS 18 stop condition; later Slice 4 source work begins only after it passes.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-28-slice-4-services-pricing.md`. Execute Tasks 1–8 in order; do not parallelize simulator/build work or bypass Task 1’s iOS 18 hard gate.
