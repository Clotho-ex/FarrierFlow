# Slice 5 — Invoicing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `superpowers:test-driven-development` for every behavior change and
> `superpowers:verification-before-completion` before reporting the slice
> complete. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn completed Client-owned WorkItems into immutable, sequentially
numbered Invoices that remain available offline, can be marked Paid, and render
as clean shareable US Letter PDFs.

**Architecture:** Preserve the established `SwiftUI View` →
`@MainActor @Observable feature model` → focused rule/use case →
`SwiftData ModelContext` direction. One first-shipping 14-model SwiftData schema
owns invoice relationships and delete rules. Invoice generation re-fetches
selected Visits, selects every currently eligible WorkItem for the receiving
Client, creates all snapshots, links each source WorkItem, and advances the
Business Profile sequence in one save. PDF drawing consumes a snapshot-only
value and never queries or mutates SwiftData.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, Observation, SwiftData,
Foundation money/date formatting, native Core Graphics/UIKit PDF and sharing
APIs, Swift Testing/XCTest, iOS 18.0 minimum, latest stable iOS 26 SDK.

## Global Constraints

- Implement only
  `docs/superpowers/specs/2026-07-30-slice-5-invoicing-design.md` on
  `codex/slice-5-invoicing`. Do not redesign the product or add a deferred
  capability.
- Preserve every explicit exclusion in the specification: no taxes, discounts,
  tips, deposits, refunds, adjustments, partial payments, payment processing,
  payment methods, overdue behavior, Draft/Sent states, recurring invoices,
  statements, multi-client invoices, custom numbering, themes, estimates,
  quotes, logos, Visit-level/travel/mileage/barn-call/emergency/shared charges,
  accounting integrations, email delivery, networking, accounts, CloudKit,
  synchronization, app-managed backup, or third-party PDF package.
- Treat Slice 5 as the first shipping store. Replace the pre-release V1–V4
  migration stack with one complete schema; do not retain migration stages,
  migration fixtures, legacy WorkItem policy fields, or compatibility
  branches.
- Keep money as nonnegative `Int64` USD minor units. Use
  `CheckedMoneyTotal` for every total and `MoneyFormatter` for every displayed
  amount. Never introduce floating-point financial arithmetic.
- One Invoice belongs to one Client. A selected Visit contributes all and only
  currently uninvoiced WorkItems whose VisitHorse Horse belongs to that Client.
  A mixed-client Visit may appear on separate Client Invoices, but one WorkItem
  may be linked to only one InvoiceLineItem.
- Generated Invoice, InvoiceVisit, and InvoiceLineItem financial/snapshot
  fields are immutable. Only `Invoice.statusRawValue` and `paidAt` may change,
  and only through Mark Paid. Do not expose a custom payment date or a
  transition back to Unpaid.
- Use native `NavigationStack`, `List`, `Form`, `Section`, `DatePicker`,
  `Menu`, `sheet`, `alert`, `confirmationDialog`, and
  `ContentUnavailableView`. Add no tab, custom navigation, generalized billing
  engine, repository layer, dependency-injection framework, document
  framework, or speculative protocol.
- Put user-facing copy in
  `FarrierFlow/Resources/Localizable.xcstrings`. Use Apple terminology,
  status text in addition to color, semantic colors, 44-point controls,
  Dynamic Type-safe layouts, and meaningful VoiceOver labels/values/hints.
- Keep feature models `@MainActor @Observable`; views own them with `@State`,
  render state, and send actions. Pass `PersistentIdentifier` values across
  routes, not live `ModelContext` or model objects.
- Before every build or test command, run these checks separately:

  ```bash
  pgrep -fl 'xcodebuild|xctest|XCTRunner'
  memory_pressure
  sysctl vm.swapusage
  ```

  Continue only when no prior test/build runner survives and memory pressure
  and swap are stable. Use one installed simulator, never clone a destination,
  never overlap commands, and stop rather than retry under resource pressure.
- Use these verified destinations:

  ```bash
  IOS18_DESTINATION='platform=iOS Simulator,id=02DB4E38-DF46-4F30-A8C8-C4D4DF46FDA4'
  IOS26_DESTINATION='platform=iOS Simulator,id=A9501C1D-4747-4310-8F2B-F0587E0E30C6'
  ```

- During Tasks 1–5, run only the listed focused iOS 26 tests. Reserve the full
  serial iOS 18/iOS 26 gates for Task 6. Do not run UI tests before Task 6.
- Before every task commit, run `git diff --check`, stage only that task's
  listed files with that task's explicit `git add --` command, inspect
  `git diff --cached --check` and `git diff --cached`, then commit. Do not
  inspect or apply any stash.

---

### Task 1: First-Shipping Schema and Invoice Domain

**Files**

- Create:
  `FarrierFlow/Core/Persistence/Schema/Visit.swift`,
  `FarrierFlow/Core/Persistence/Schema/VisitHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/Photograph.swift`,
  `FarrierFlow/Core/Persistence/Schema/Service.swift`,
  `FarrierFlow/Core/Persistence/Schema/WorkItem.swift`,
  `FarrierFlow/Core/Persistence/Schema/BusinessProfile.swift`,
  `FarrierFlow/Core/Persistence/Schema/Invoice.swift`,
  `FarrierFlow/Core/Persistence/Schema/InvoiceVisit.swift`,
  `FarrierFlow/Core/Persistence/Schema/InvoiceLineItem.swift`,
  `FarrierFlow/Features/Invoices/InvoiceStatus.swift`,
  `FarrierFlow/Features/Invoices/InvoiceDomainRules.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceDomainRulesTests.swift`
- Modify:
  `FarrierFlow/Core/Persistence/Schema/FarrierFlowSchemaV1.swift`,
  `FarrierFlow/Core/Persistence/Schema/Client.swift`,
  `FarrierFlow/Core/Persistence/Schema/Barn.swift`,
  `FarrierFlow/Core/Persistence/Schema/Horse.swift`,
  `FarrierFlow/Core/Persistence/Schema/Appointment.swift`,
  `FarrierFlow/Core/Persistence/Schema/AppointmentHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/CurrentSchema.swift`,
  `FarrierFlow/Core/Persistence/ModelContainerFactory.swift`,
  `FarrierFlow/Core/Persistence/DomainGraphValidator.swift`,
  `FarrierFlow/Core/Persistence/RecordDeletionRules.swift`,
  `FarrierFlow/Features/Horses/HorseDetailModel.swift`,
  `FarrierFlow/Features/Horses/HorseHistoryRules.swift`,
  `FarrierFlow/Features/Horses/Models/HorseHistoryEntry.swift`,
  `FarrierFlow/Features/Visits/Models/VisitDraft.swift`,
  `FarrierFlow/Features/Visits/VisitDetailModel.swift`,
  `FarrierFlow/Features/Visits/VisitRules.swift`,
  `FarrierFlow/Features/Visits/VisitSaveUseCase.swift`,
  `FarrierFlow/Features/Visits/VisitStartUseCase.swift`,
  `FarrierFlowTests/Support/ModelFixtures.swift`,
  `FarrierFlowTests/Core/Persistence/SchemaContractTests.swift`,
  `FarrierFlowTests/Core/Persistence/ModelContainerFactoryTests.swift`,
  `FarrierFlowTests/Core/Persistence/SwiftDataRelationshipInsertionTests.swift`,
  `FarrierFlowTests/Core/Persistence/DomainGraphValidatorTests.swift`,
  `FarrierFlowTests/Core/Persistence/RecordDeletionRulesTests.swift`,
  `FarrierFlowTests/Core/Persistence/WorkItemDomainValidationTests.swift`,
  `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`,
  `FarrierFlowTests/Features/Horses/HorseHistoryRulesTests.swift`,
  `FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift`,
  `FarrierFlowTests/Features/Visits/VisitRulesTests.swift`,
  `FarrierFlowTests/Features/Visits/VisitStartUseCaseTests.swift`
- Delete:
  `FarrierFlow/Core/Persistence/Migrations/FarrierFlowMigrationPlan.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/FarrierFlowSchemaV2.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/V2Client.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/V2Barn.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/V2Horse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/V2Appointment.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/V2AppointmentHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/V2Visit.swift`,
  `FarrierFlow/Core/Persistence/Schema/V2/V2VisitHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/FarrierFlowSchemaV3.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3Client.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3Barn.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3Horse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3Appointment.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3AppointmentHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3Visit.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3VisitHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V3/V3Photograph.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/FarrierFlowSchemaV4.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4Client.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4Barn.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4Horse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4Appointment.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4AppointmentHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4Visit.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4VisitHorse.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4Photograph.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4Service.swift`,
  `FarrierFlow/Core/Persistence/Schema/V4/V4WorkItem.swift`,
  `FarrierFlowTests/Core/Persistence/SchemaMigrationTests.swift`,
  `FarrierFlowTests/Support/V1StoreFixture.swift`,
  `FarrierFlowTests/Support/V2StoreFixture.swift`

**Interfaces produced and consumed**

- Produce `FarrierFlowSchemaV1` as the first shipping
  `Schema.Version(1, 0, 0)` containing exactly Client, Barn, Horse,
  Appointment, AppointmentHorse, Visit, VisitHorse, Photograph, Service,
  WorkItem, BusinessProfile, Invoice, InvoiceVisit, and InvoiceLineItem.
  `CurrentSchema` aliases all 14 types, and every container configuration
  registers this same schema without a migration plan.
- Produce one `BusinessProfile` with normalized optional contact/default-note
  fields and `nextInvoiceNumber: Int64`, defaulting to `1`.
- Produce `nonisolated enum InvoiceStatus: String, CaseIterable, Codable {
  case unpaid, paid }`.
- Produce `Invoice` with `@Attribute(.unique) number: Int64`,
  dates/note/status/payment date, required-domain/optional-storage `client`,
  Client and Business snapshot fields, explicit `USD`, and at least one
  cascade-owned `InvoiceVisit`. Do not persist a redundant Invoice total;
  derive it from immutable line amounts.
- Produce `InvoiceVisit` with required-domain/optional-storage `invoice` and
  `sourceVisit`, immutable Visit date/location snapshots, and cascade-owned
  `[InvoiceLineItem]`. `Invoice.invoiceVisits` permits only one group per
  source Visit inside that Invoice; `Visit.invoiceVisits` is not globally
  unique.
- Produce `InvoiceLineItem` with required-domain/optional-storage
  `invoiceVisit` and `sourceWorkItem`, Horse/Service/amount/currency snapshots.
  The one-to-one inverse `WorkItem.invoiceLineItem` is the global
  duplicate-billing boundary, and each InvoiceVisit owns at least one line.
- Extend `Client.invoices`, `Visit.invoiceVisits`, and
  `WorkItem.invoiceLineItem` with deny/nullify rules that block source deletion
  while referenced but allow cascade deletion of an Unpaid Invoice to clear
  only its inverse billing links.
- Produce:

  ```swift
  @MainActor enum InvoiceDomainRules {
      static func validatedStatus(
          rawValue: String,
          paidAt: Date?
      ) throws -> InvoiceStatus
      static func formattedNumber(_ number: Int64) throws -> String
      static func checkedTotal(
          _ amounts: [Int64]
      ) throws -> Int64
      static func isCorrectionLocked(_ visit: Visit) -> Bool
      static func orderedVisits(
          _ visits: [InvoiceVisit],
          locale: Locale
      ) -> [InvoiceVisit]
      static func orderedLineItems(
          _ lineItems: [InvoiceLineItem],
          locale: Locale
      ) -> [InvoiceLineItem]
  }
  ```

  `DomainGraphValidator`, invoice feature models/use cases, Visit correction,
  list/detail display, and PDF assembly consume these rules.
- Remove `workItemPolicyVersion` and every policy-0 compatibility projection.
  With no pre-release migration, every completed serviced VisitHorse follows
  the current WorkItem contract.

- [ ] **Write focused failing tests first.**

  Assert the exact 14-model schema, production/preview/in-memory/temporary
  container parity, inverse cardinality and delete rules, one Business Profile
  sequence default, Invoice status/date consistency, positive unique numbers,
  four-digit minimum number formatting without truncating values above 9999,
  one source Visit per Invoice, one InvoiceLineItem per WorkItem, nonnegative
  USD amounts, checked totals, Client ownership alignment, and no legacy
  policy/migration symbols. Add deletion tests proving the Business Profile and
  referenced Clients, Visits, and WorkItems cannot be removed through domain
  mutation.

- [ ] **Run the focused failure gate.**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/SchemaContractTests \
    -only-testing:FarrierFlowTests/ModelContainerFactoryTests \
    -only-testing:FarrierFlowTests/SwiftDataRelationshipInsertionTests \
    -only-testing:FarrierFlowTests/DomainGraphValidatorTests \
    -only-testing:FarrierFlowTests/RecordDeletionRulesTests \
    -only-testing:FarrierFlowTests/WorkItemDomainValidationTests \
    -only-testing:FarrierFlowTests/InvoiceDomainRulesTests \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests \
    -only-testing:FarrierFlowTests/HorseHistoryRulesTests \
    -only-testing:FarrierFlowTests/VisitDetailModelTests \
    -only-testing:FarrierFlowTests/VisitRulesTests \
    -only-testing:FarrierFlowTests/VisitStartUseCaseTests
  ```

  Expected: FAIL because the first-shipping Invoice types and relationships do
  not exist and the container still registers V4 plus a migration plan.

- [ ] **Implement the minimal first-shipping schema.**

  Move the current V4 product shapes into the root V1 namespace, add the four
  Invoice models, update aliases/containers, and delete V2–V4 plus migration
  code and fixtures. Remove policy fields/branches from Visit creation,
  validation, history, and tests; do not add a migration or store-reset path to
  production code.

- [ ] **Implement complete-graph and deletion validation.**

  Validate every required optional-storage relationship and inverse, singleton
  Business Profile, sequence positivity, number uniqueness, snapshot
  normalization, exact `USD`, status/payment-date pairing, one source Visit per
  Invoice, WorkItem-to-Client ownership, WorkItem global uniqueness, immutable
  line amounts, and checked derived Invoice total. Require
  `nextInvoiceNumber` to be positive and greater than every persisted Invoice
  number. Extend typed deletion preflight for the nondeletable Business Profile
  and for Client/Visit/WorkItem invoice references without weakening SwiftData
  delete rules.

- [ ] **Rerun the focused gate and commit.**

  Expected: PASS with no migration test target or legacy policy behavior.

  ```bash
  git add -- FarrierFlow/Core/Persistence/Schema \
    FarrierFlow/Core/Persistence/Migrations/FarrierFlowMigrationPlan.swift \
    FarrierFlow/Core/Persistence/ModelContainerFactory.swift \
    FarrierFlow/Core/Persistence/DomainGraphValidator.swift \
    FarrierFlow/Core/Persistence/RecordDeletionRules.swift \
    FarrierFlow/Features/Horses/HorseDetailModel.swift \
    FarrierFlow/Features/Horses/HorseHistoryRules.swift \
    FarrierFlow/Features/Horses/Models/HorseHistoryEntry.swift \
    FarrierFlow/Features/Visits/Models/VisitDraft.swift \
    FarrierFlow/Features/Visits/VisitDetailModel.swift \
    FarrierFlow/Features/Visits/VisitRules.swift \
    FarrierFlow/Features/Visits/VisitSaveUseCase.swift \
    FarrierFlow/Features/Visits/VisitStartUseCase.swift \
    FarrierFlow/Features/Invoices/InvoiceStatus.swift \
    FarrierFlow/Features/Invoices/InvoiceDomainRules.swift \
    FarrierFlowTests/Core/Persistence \
    FarrierFlowTests/Features/Horses/HorseHistoryRulesTests.swift \
    FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift \
    FarrierFlowTests/Features/Visits/VisitRulesTests.swift \
    FarrierFlowTests/Features/Visits/VisitStartUseCaseTests.swift \
    FarrierFlowTests/Features/Invoices/InvoiceDomainRulesTests.swift \
    FarrierFlowTests/Support/ModelFixtures.swift \
    FarrierFlowTests/Support/V1StoreFixture.swift \
    FarrierFlowTests/Support/V2StoreFixture.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: establish first-shipping invoice schema"
  ```

---

### Task 2: Business Profile

**Files**

- Create:
  `FarrierFlow/Features/BusinessProfile/Models/BusinessProfileDraft.swift`,
  `FarrierFlow/Features/BusinessProfile/BusinessProfileRules.swift`,
  `FarrierFlow/Features/BusinessProfile/BusinessProfileEditorModel.swift`,
  `FarrierFlow/Features/BusinessProfile/BusinessProfileRoutes.swift`,
  `FarrierFlow/Features/BusinessProfile/Views/BusinessProfileEditorView.swift`,
  `FarrierFlowTests/Features/BusinessProfile/BusinessProfileRulesTests.swift`,
  `FarrierFlowTests/Features/BusinessProfile/BusinessProfileEditorModelTests.swift`
- Modify:
  `FarrierFlow/Features/Clients/Views/ClientListView.swift`,
  `FarrierFlow/Resources/Localizable.xcstrings`

**Interfaces produced and consumed**

- Produce:

  ```swift
  struct BusinessProfileDraft: Equatable {
      var name: String
      var phone: String
      var email: String
      var address: String
      var defaultInvoiceNote: String
  }

  struct BusinessProfileValues: Equatable {
      let name: String
      let phone: String?
      let email: String?
      let address: String?
      let defaultInvoiceNote: String?
  }

  nonisolated enum BusinessProfileRules {
      static func validated(
          _ draft: BusinessProfileDraft
      ) throws -> BusinessProfileValues
  }
  ```

- Produce `@MainActor @Observable final class BusinessProfileEditorModel` with
  `draft`, `loadState`, `canSave`, `alert`, `load(in:)`, and `save(in:)`.
  `load(in:)` edits the sole existing record or initializes an unsaved draft;
  `save(in:)` creates the sole record with sequence `1` or updates only its
  editable fields, validates the complete graph, and preserves the sequence.
- Produce `enum BusinessProfileRoute: Hashable { case editor }` and
  `BusinessProfileEditorView(onSaved: (() -> Void)? = nil)`. Clients > More
  consumes the route; Task 4's missing-profile prerequisite consumes
  `onSaved`.

- [ ] **Write focused failing tests first.**

  Cover required normalized name, normalized optional fields, clearing optional
  fields, create-versus-edit behavior, prevention of a second profile, retained
  `nextInvoiceNumber`, failed-save rollback, and existing-Invoice snapshot
  isolation after profile edits.

- [ ] **Run the focused failure gate.**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/BusinessProfileRulesTests \
    -only-testing:FarrierFlowTests/BusinessProfileEditorModelTests
  ```

  Expected: FAIL because the Business Profile rules/model are not implemented.

- [ ] **Implement validation and persistence.**

  Reuse `TextNormalization`; do not reject optional phone/email based on
  regional formatting. Fetch at most one profile, fail closed if persisted
  duplicates exist, and use the existing complete-graph save/rollback boundary.
  Editing must never touch Invoice snapshots or expose the sequence.

- [ ] **Implement the native editor and navigation.**

  Add Business Profile beside Service Locations and Services in Clients >
  More. Use a pushed `Form` with required name, optional phone/email/address,
  optional default note, inline validation, loading/unavailable states, and
  standard Save. Keep the draft on recoverable errors and invoke `onSaved`
  only after persistence succeeds.

- [ ] **Rerun the focused gate and commit.**

  Expected: PASS; profile create/edit is offline, singleton-safe, and snapshot
  preserving.

  ```bash
  git add -- FarrierFlow/Features/BusinessProfile \
    FarrierFlow/Features/Clients/Views/ClientListView.swift \
    FarrierFlow/Resources/Localizable.xcstrings \
    FarrierFlowTests/Features/BusinessProfile
  git diff --cached --check
  git diff --cached
  git commit -m "feat: add business profile"
  ```

---

### Task 3: Invoice Eligibility and Generation

**Files**

- Create:
  `FarrierFlow/Features/Invoices/Models/InvoiceVisitChoice.swift`,
  `FarrierFlow/Features/Invoices/Models/InvoiceCreationDraft.swift`,
  `FarrierFlow/Features/Invoices/InvoiceDateRules.swift`,
  `FarrierFlow/Features/Invoices/InvoiceEligibilityRules.swift`,
  `FarrierFlow/Features/Invoices/InvoiceGenerationUseCase.swift`,
  `FarrierFlow/Features/Invoices/InvoiceCreationModel.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceDateRulesTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceEligibilityRulesTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceGenerationUseCaseTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceCreationModelTests.swift`
- Modify:
  `FarrierFlow/Features/Visits/VisitSaveUseCase.swift`,
  `FarrierFlow/Features/Visits/VisitEditorModel.swift`,
  `FarrierFlow/Features/Visits/VisitDetailModel.swift`,
  `FarrierFlow/Features/Visits/Views/VisitDetailView.swift`,
  `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`,
  `FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift`,
  `FarrierFlowTests/Core/Persistence/DomainGraphValidatorTests.swift`,
  `FarrierFlowTests/Support/ModelFixtures.swift`

**Interfaces produced and consumed**

- Produce:

  ```swift
  struct InvoiceVisitChoice: Identifiable, Equatable {
      let id: PersistentIdentifier
      let visitDate: Date
      let serviceLocationName: String
      let eligibleWorkItemCount: Int
      let subtotalMinorUnits: Int64
  }

  struct InvoiceCreationDraft: Equatable {
      let clientID: PersistentIdentifier
      var selectedVisitIDs: Set<PersistentIdentifier>
      var invoiceDate: Date
      var dueDate: Date?
      var note: String
  }
  ```

- Produce
  `InvoiceDateRules.defaultDueDate(for:calendar:) throws -> Date`, adding 14
  calendar days rather than a fixed number of seconds.
- Produce:

  ```swift
  @MainActor enum InvoiceEligibilityRules {
      static func choices(
          for clientID: PersistentIdentifier,
          in context: ModelContext
      ) throws -> [InvoiceVisitChoice]
  }

  @MainActor enum InvoiceGenerationUseCase {
      static func generate(
          _ draft: InvoiceCreationDraft,
          in context: ModelContext
      ) throws -> PersistentIdentifier
  }
  ```

- Produce `@MainActor @Observable final class InvoiceCreationModel` with
  `draft`, `clientName`, `visitChoices`, `hasValidBusinessProfile`,
  `loadState`, `canGenerate`, `isGenerating`, `alert`, `load(in:now:calendar:)`,
  `toggleVisit(_:)`, `selectAll()`, and `generate(in:)`.
  Task 4's creation view consumes this model; there is no per-WorkItem
  selection interface.
- Extend Visit correction with
  `VisitSaveError.invoicedVisitCannotBeCorrected`. `VisitSaveUseCase.editorMode`,
  `loadDraft`, and `saveCorrection` consume
  `InvoiceDomainRules.isCorrectionLocked(_:)`; Visit Detail consumes the
  resulting read-only reason.

- [ ] **Write focused failing eligibility and generation tests first.**

  Cover completed-only eligibility; the receiving Client ownership chain;
  mixed-client Visit choices for each represented Client; exclusion of another
  Client's WorkItems; exclusion of already linked WorkItems; deterministic
  Visit ordering; checked subtotals; Select All; default/cleared due date;
  default/edited/cleared note; and absence of any line-selection state.

  For generation, prove every currently eligible Client WorkItem from each
  selected Visit is included automatically; all source and Client/Business/
  Visit/Horse/Service/date/amount snapshots are exact; Visit groups and lines
  are deterministically ordered; duplicate WorkItem billing and duplicate
  source Visit within one Invoice fail; another Client's portion remains
  eligible; first number is `0001`; later numbers advance; and
  invalid/overflow/repeated generation leaves no Invoice, snapshots, links, or
  sequence change.

  Add Visit tests proving any InvoiceLineItem locks whole-Visit correction,
  read-only detail/photo access remains, and another Client's eligible portion
  can still generate while locked.

- [ ] **Run the focused failure gate.**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/InvoiceDateRulesTests \
    -only-testing:FarrierFlowTests/InvoiceEligibilityRulesTests \
    -only-testing:FarrierFlowTests/InvoiceGenerationUseCaseTests \
    -only-testing:FarrierFlowTests/InvoiceCreationModelTests \
    -only-testing:FarrierFlowTests/VisitEditorModelTests \
    -only-testing:FarrierFlowTests/VisitDetailModelTests
  ```

  Expected: FAIL because per-Client eligibility, generation, Select All, and
  invoice-aware correction locking do not exist.

- [ ] **Implement fail-closed eligibility and transient selection.**

  Fetch completed Visits and derive candidates only through
  `WorkItem → VisitHorse → Horse → Client`. Exclude linked WorkItems, omit
  Visits with no remaining items for this Client, checked-sum each row, and
  sort by Visit date, service-location name, then persistent identity. Keep
  selection as Visit identifiers; when loading/reloading, intersect it with
  current eligible choices. `selectAll()` selects exactly the displayed
  eligible Visit identifiers.

- [ ] **Implement one atomic generation action.**

  Re-fetch Client, Business Profile, selected Visits, and eligible WorkItems in
  the action context; do not trust cached row counts or totals. Revalidate every
  relationship, ownership, status, currency, amount, and existing billing
  link. Create one InvoiceVisit per selected Visit and one InvoiceLineItem for
  every eligible Client WorkItem, link inverses, derive and validate the
  checked total, assign the current positive sequence, increment with checked
  arithmetic, run complete-graph validation, and save once. On any failure,
  roll back the context and preserve safe form choices; never consume a number
  or partial link.

- [ ] **Apply one deterministic snapshot ordering.**

  Use the shared ordering rules everywhere: Visit date ascending, then
  service-location name and stable persistent identity; lines by Horse name,
  Service name, amount, then stable source WorkItem identity. Detail and PDF
  consume the same ordered projections rather than relying on SwiftData
  relationship-array order.

- [ ] **Lock completed Visit correction at every mutation boundary.**

  Fail before draft editing and recheck immediately before correction save if
  any WorkItem in any VisitHorse has an InvoiceLineItem. Show Visit Detail
  read-only with a concise invoiced-work explanation. Do not block invoice
  generation, detail reading, or photographs.

- [ ] **Rerun the focused gate and commit.**

  Expected: PASS for per-Client mixed-Visit generation, atomic numbering,
  WorkItem uniqueness, and correction locking.

  ```bash
  git add -- FarrierFlow/Features/Invoices/Models/InvoiceVisitChoice.swift \
    FarrierFlow/Features/Invoices/Models/InvoiceCreationDraft.swift \
    FarrierFlow/Features/Invoices/InvoiceDateRules.swift \
    FarrierFlow/Features/Invoices/InvoiceEligibilityRules.swift \
    FarrierFlow/Features/Invoices/InvoiceGenerationUseCase.swift \
    FarrierFlow/Features/Invoices/InvoiceCreationModel.swift \
    FarrierFlow/Features/Visits/VisitSaveUseCase.swift \
    FarrierFlow/Features/Visits/VisitEditorModel.swift \
    FarrierFlow/Features/Visits/VisitDetailModel.swift \
    FarrierFlow/Features/Visits/Views/VisitDetailView.swift \
    FarrierFlowTests/Features/Invoices/InvoiceDateRulesTests.swift \
    FarrierFlowTests/Features/Invoices/InvoiceEligibilityRulesTests.swift \
    FarrierFlowTests/Features/Invoices/InvoiceGenerationUseCaseTests.swift \
    FarrierFlowTests/Features/Invoices/InvoiceCreationModelTests.swift \
    FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift \
    FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift \
    FarrierFlowTests/Core/Persistence/DomainGraphValidatorTests.swift \
    FarrierFlowTests/Support/ModelFixtures.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: generate client invoices"
  ```

---

### Task 4: Invoice List, Detail, Status, and Deletion

**Files**

- Create:
  `FarrierFlow/Features/Invoices/Models/InvoiceSummary.swift`,
  `FarrierFlow/Features/Invoices/Models/InvoiceDetail.swift`,
  `FarrierFlow/Features/Invoices/InvoiceRoutes.swift`,
  `FarrierFlow/Features/Invoices/InvoiceListModel.swift`,
  `FarrierFlow/Features/Invoices/InvoiceDetailModel.swift`,
  `FarrierFlow/Features/Invoices/InvoiceStatusUseCase.swift`,
  `FarrierFlow/Features/Invoices/InvoiceDeletionUseCase.swift`,
  `FarrierFlow/Features/Invoices/Components/InvoiceRow.swift`,
  `FarrierFlow/Features/Invoices/Components/InvoiceVisitSelectionRow.swift`,
  `FarrierFlow/Features/Invoices/Components/InvoiceLineItemRow.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceCreationView.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceListView.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceListModelTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceDetailModelTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceStatusUseCaseTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoiceDeletionUseCaseTests.swift`
- Modify:
  `FarrierFlow/Features/Clients/ClientDetailModel.swift`,
  `FarrierFlow/Features/Clients/Views/ClientDetailView.swift`,
  `FarrierFlow/Features/Clients/Views/ClientListView.swift`,
  `FarrierFlowTests/Features/Clients/ClientDraftAndModelTests.swift`,
  `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`,
  `FarrierFlow/Resources/Localizable.xcstrings`

**Interfaces produced and consumed**

- Produce:

  ```swift
  enum InvoiceRoute: Hashable {
      case list
      case detail(PersistentIdentifier)
      case create(PersistentIdentifier)
  }

  struct InvoiceSummary: Identifiable, Equatable {
      let id: PersistentIdentifier
      let number: String
      let clientName: String
      let invoiceDate: Date
      let total: MoneyAvailability
      let status: InvoiceStatus
  }
  ```

- Produce immutable `InvoiceDetail` with Business/Client snapshots, formatted
  number, dates, status/payment date, ordered Visit groups and line snapshots,
  note, and `MoneyAvailability` total. It contains no mutable source model.
- Produce `@MainActor @Observable InvoiceListModel` with `load(in:locale:)`,
  descending-number summaries, loading/empty/failed states, and Retry.
- Produce `@MainActor @Observable InvoiceDetailModel` with
  `load(invoiceID:in:locale:)`, `markPaid(now:in:)`, and `delete(in:)`.
  It publishes immutable detail state, action availability, confirmation/error
  state, and successful deletion.
- Produce
  `InvoiceCreationView(clientID:onGenerated:)`; the Clients navigation owner
  consumes its generated Invoice identifier by replacing the creation route
  with `InvoiceRoute.detail`. No temporary detail route or live SwiftData
  model crosses the navigation boundary.
- Produce:

  ```swift
  @MainActor enum InvoiceStatusUseCase {
      static func markPaid(
          invoiceID: PersistentIdentifier,
          paidAt: Date,
          in context: ModelContext
      ) throws
  }

  @MainActor enum InvoiceDeletionUseCase {
      static func deleteUnpaid(
          invoiceID: PersistentIdentifier,
          in context: ModelContext
      ) throws
  }
  ```

  Task 5 consumes `InvoiceDetailModel` for Share PDF.

- [ ] **Write focused failing tests first.**

  Cover descending Invoice list order and snapshot-only Client names; checked
  total/unavailable display; Unpaid/Paid text; detail grouping/order; Mark Paid
  setting status and current payment date atomically; repeat Mark Paid failure;
  Paid delete denial; Unpaid cascade deletion; released billing links for only
  that Invoice; sequence non-reuse; mixed-client remaining references; Visit
  correction becoming available only after its last line reference is removed;
  Paid references retaining the lock; Client deletion blocked by any Invoice;
  and persistent reopening of profile, snapshots, source relationships, status,
  payment date, sequence, and released links.

- [ ] **Run the focused failure gate.**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/InvoiceListModelTests \
    -only-testing:FarrierFlowTests/InvoiceDetailModelTests \
    -only-testing:FarrierFlowTests/InvoiceStatusUseCaseTests \
    -only-testing:FarrierFlowTests/InvoiceDeletionUseCaseTests \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests \
    -only-testing:FarrierFlowTests/ClientDraftAndModelTests
  ```

  Expected: FAIL because Invoice navigation, projections, status, deletion,
  and reopening behavior are absent.

- [ ] **Implement status, deletion, and display projections.**

  Mark Paid re-fetches an Unpaid Invoice, validates the current graph, assigns
  `.paid` plus `paidAt`, and saves once; failure rolls back both values.
  Deletion re-fetches an Unpaid Invoice, records its affected source Visits,
  deletes only the Invoice cascade, validates that source records remain and
  inverses clear, then saves once; failure rolls back the full graph. List and
  detail projections read only persisted snapshots and checked totals, never
  current Client/Horse/Service/Barn text.

- [ ] **Implement native creation, list, and detail surfaces.**

  Add Invoices and Business Profile to Clients > More without a new tab. Add
  Create Invoice to Client Detail. The creation `Form` shows read-only Client,
  eligible Visit rows, individual selection, a plainly labeled Select All,
  invoice/due dates, optional note, missing-profile guidance that opens the
  Task 2 editor and reloads on save, preserved retryable errors, and Generate
  only when valid. Successful generation replaces the creation route with
  Invoice Detail.

  Use a native Invoice `List` with number, Client snapshot, date, localized
  total, and textual status. Detail shows snapshot information and Visit-date
  groups, exposes Mark Paid only for Unpaid, and puts Unpaid Delete behind
  destructive confirmation. Invalid totals display unavailable and disable
  unsafe financial actions; no amount is wrapped or approximated.

- [ ] **Rerun the focused gate and commit.**

  Expected: PASS for UI-driving models, Mark Paid, exact Unpaid release rules,
  Client deletion blocking, and persistent reopening.

  ```bash
  git add -- FarrierFlow/Features/Invoices/Models/InvoiceSummary.swift \
    FarrierFlow/Features/Invoices/Models/InvoiceDetail.swift \
    FarrierFlow/Features/Invoices/InvoiceRoutes.swift \
    FarrierFlow/Features/Invoices/InvoiceListModel.swift \
    FarrierFlow/Features/Invoices/InvoiceDetailModel.swift \
    FarrierFlow/Features/Invoices/InvoiceStatusUseCase.swift \
    FarrierFlow/Features/Invoices/InvoiceDeletionUseCase.swift \
    FarrierFlow/Features/Invoices/Components/InvoiceRow.swift \
    FarrierFlow/Features/Invoices/Components/InvoiceVisitSelectionRow.swift \
    FarrierFlow/Features/Invoices/Components/InvoiceLineItemRow.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceCreationView.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceListView.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift \
    FarrierFlow/Features/Clients/ClientDetailModel.swift \
    FarrierFlow/Features/Clients/Views/ClientDetailView.swift \
    FarrierFlow/Features/Clients/Views/ClientListView.swift \
    FarrierFlow/Resources/Localizable.xcstrings \
    FarrierFlowTests/Features/Invoices/InvoiceListModelTests.swift \
    FarrierFlowTests/Features/Invoices/InvoiceDetailModelTests.swift \
    FarrierFlowTests/Features/Invoices/InvoiceStatusUseCaseTests.swift \
    FarrierFlowTests/Features/Invoices/InvoiceDeletionUseCaseTests.swift \
    FarrierFlowTests/Features/Clients/ClientDraftAndModelTests.swift \
    FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: manage invoice history and status"
  ```

---

### Task 5: Native PDF and Sharing

**Files**

- Create:
  `FarrierFlow/Features/Invoices/PDF/InvoicePDFContent.swift`,
  `FarrierFlow/Features/Invoices/PDF/InvoicePDFContentBuilder.swift`,
  `FarrierFlow/Features/Invoices/PDF/InvoicePDFRenderer.swift`,
  `FarrierFlow/Features/Invoices/PDF/InvoicePDFTemporaryFileStore.swift`,
  `FarrierFlow/Features/Invoices/InvoicePDFShareModel.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceShareSheet.swift`,
  `FarrierFlowTests/Features/Invoices/InvoicePDFContentBuilderTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoicePDFRendererTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoicePDFTemporaryFileStoreTests.swift`,
  `FarrierFlowTests/Features/Invoices/InvoicePDFShareModelTests.swift`
- Modify:
  `FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift`,
  `FarrierFlow/Resources/Localizable.xcstrings`

**Interfaces produced and consumed**

- Produce immutable, `Sendable`, snapshot-only `InvoicePDFContent` with
  Business/Client information, Invoice metadata/status, ordered Visit groups,
  line snapshots, checked total, and optional note. No SwiftData model or
  relationship is retained.
- Produce:

  ```swift
  @MainActor enum InvoicePDFContentBuilder {
      static func build(
          invoiceID: PersistentIdentifier,
          in context: ModelContext
      ) throws -> InvoicePDFContent
  }

  @MainActor struct InvoicePDFRenderer {
      static let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
      func render(_ content: InvoicePDFContent) throws -> Data
  }
  ```

- Produce `InvoicePDFTemporaryFileStore` with an injected temporary directory,
  `write(_ data:number:) throws -> URL`, and
  `removeIfPresent(_:)`. The filename is exactly
  `Invoice-\(formattedNumber).pdf`.
- Produce `@MainActor @Observable InvoicePDFShareModel` with
  `prepare(invoiceID:in:)`, `shareURL`, `isPreparing`, `alert`, `retry(in:)`,
  and `sharingCompleted()`. It owns temporary-file lifetime and performs
  best-effort cleanup after the share controller completes.
- Produce `InvoiceShareSheet: UIViewControllerRepresentable` backed only by
  `UIActivityViewController`, with a completion callback. Invoice Detail
  consumes the share model and item-driven sheet.

- [ ] **Write focused failing PDF tests first.**

  Prove the builder uses only persisted Invoice snapshots after source
  Client/Business/Horse/Service/Barn edits; rejects unavailable/overflowing
  totals; preserves Visit/line order; and includes Paid/payment-date state.
  Prove the renderer emits a valid PDF with 612×792-point media boxes, one page
  for short content, multiple pages for long content, repeated readable page
  structure, and no clipping of the final total/note. Prove the exact sanitized
  filename, temporary-file contents, cleanup after completion, retry after
  render/write failure, and no Invoice mutation on any PDF failure.

- [ ] **Run the focused failure gate.**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/InvoicePDFContentBuilderTests \
    -only-testing:FarrierFlowTests/InvoicePDFRendererTests \
    -only-testing:FarrierFlowTests/InvoicePDFTemporaryFileStoreTests \
    -only-testing:FarrierFlowTests/InvoicePDFShareModelTests
  ```

  Expected: FAIL because snapshot assembly, PDF pagination, temporary-file
  lifecycle, and sharing state do not exist.

- [ ] **Implement snapshot assembly and native multi-page drawing.**

  Re-fetch one Invoice and convert it to `InvoicePDFContent` before drawing.
  Use native PDF drawing APIs, system typefaces, a restrained black-and-white
  hierarchy, fixed margins, measured text, and a page-break function that
  starts another 612×792 page before a Visit heading, line, total, status, or
  note would clip. Repeat enough document context on continuation pages for
  clarity. Do not shrink text below the chosen readable styles and do not
  consult source records.

- [ ] **Implement native sharing and cleanup.**

  Generate on demand, write one temporary file, present
  `UIActivityViewController`, retain the URL until its completion handler, then
  remove it best-effort and clear model state. A prepare failure leaves the
  Invoice unchanged, shows a native alert with Retry, and never presents a
  missing/partial file.

- [ ] **Rerun the focused gate and commit.**

  Expected: PASS for snapshot isolation, valid multi-page US Letter output,
  exact filename, retry, and file cleanup.

  ```bash
  git add -- FarrierFlow/Features/Invoices/PDF \
    FarrierFlow/Features/Invoices/InvoicePDFShareModel.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceShareSheet.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift \
    FarrierFlow/Resources/Localizable.xcstrings \
    FarrierFlowTests/Features/Invoices/InvoicePDFContentBuilderTests.swift \
    FarrierFlowTests/Features/Invoices/InvoicePDFRendererTests.swift \
    FarrierFlowTests/Features/Invoices/InvoicePDFTemporaryFileStoreTests.swift \
    FarrierFlowTests/Features/Invoices/InvoicePDFShareModelTests.swift
  git diff --cached --check
  git diff --cached
  git commit -m "feat: share invoice PDFs"
  ```

---

### Task 6: Final Integration and V1 Polish

**Files**

- Create:
  `FarrierFlowUITests/InvoiceFlowUITests.swift`
- Modify:
  `FarrierFlow/Core/Persistence/PreviewFixtures.swift`,
  `FarrierFlow/App/UITestLaunchConfiguration.swift`,
  `FarrierFlow/Features/Clients/Views/ClientListView.swift`,
  `FarrierFlow/Features/Clients/Views/ClientDetailView.swift`,
  `FarrierFlow/Features/BusinessProfile/Views/BusinessProfileEditorView.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceCreationView.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceListView.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift`,
  `FarrierFlow/Features/Invoices/Views/InvoiceShareSheet.swift`,
  `FarrierFlow/Resources/Localizable.xcstrings`,
  `FarrierFlowUITests/RootNavigationUITests.swift`,
  `FarrierFlowUITests/EditorAccessibilityUITests.swift`,
  `FarrierFlowUITests/BlockedMutationUITests.swift`,
  `FarrierFlowUITests/FormatterDisplayUITests.swift`,
  `PRODUCT.md`,
  `DESIGN.md`,
  `ARCHITECTURE.md`,
  `DATA_MODEL.md`,
  `ROADMAP.md`

**Interfaces produced and consumed**

- Produce stable accessibility identifiers only for UI-test entry points:
  Business Profile fields/save, Create Invoice, Visit selection/Select All,
  Generate, Invoice row/detail, Share PDF, Mark Paid, and confirmed Delete.
- Extend `UITestLaunchConfiguration` with deterministic first-shipping
  scenarios: one starts without a Business Profile but has a single-client and
  a mixed-client completed Visit with uninvoiced WorkItems; another opens
  persisted Invoice history. Fixtures use the same production schema and public
  use cases; they do not bypass domain rules.
- Produce one focused acceptance flow in `InvoiceFlowUITests`:
  Client Detail → Create Invoice → select mixed-client Visit/Select All →
  Generate → verify snapshot lines/total → open native share sheet and cancel
  → Mark Paid → relaunch → verify Paid history and unavailable correction.
- Update the five product/architecture documents to describe the implemented
  first-shipping schema and completed Slice 5 behavior. Do not add later
  roadmap decisions.

- [ ] **Write the focused UI acceptance test before polish changes.**

  Add assertions for Clients > More navigation to Invoices and Business
  Profile; missing-profile completion returning to creation; empty/no-eligible
  states; all eligible Client lines and no other Client lines; textual Unpaid/
  Paid status; share sheet entry; Mark Paid; Paid deletion absence; correction
  lock copy; relaunch persistence; and large Dynamic Type accessibility labels
  for the primary flow. Keep this one focused flow, not an exhaustive UI
  matrix; Unpaid deletion remains covered by Task 4's transaction tests.

- [ ] **Run only the focused Invoice UI test on iOS 26 and confirm failure.**

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests/InvoiceFlowUITests
  ```

  Expected: FAIL on missing fixture identifiers or unfinished integration
  polish, not on simulator concurrency.

- [ ] **Complete localization, accessibility, and native state polish.**

  Add deterministic fixtures and identifiers. Audit every Slice 5 string for
  catalog coverage and concise Apple-style terminology. Verify selection,
  status, totals, destructive actions, error/retry, empty/no-eligible,
  missing-profile, unavailable-record, and PDF-failure states are conveyed in
  text and VoiceOver. Check Dynamic Type wrapping, semantic contrast, 44-point
  hit targets, keyboard types/content types, Reduce Motion, Light/Dark Mode,
  and one-handed action placement. Use no decorative cards, custom navigation,
  or manual Liquid Glass.

- [ ] **Update repository truth and inspect the complete Slice 5 diff.**

  Update `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, and
  `ROADMAP.md` from implemented behavior: Slice 5 complete, 14-model first
  shipping schema, no pre-release migration support, mixed-client WorkItem
  billing, Visit locking/release rules, snapshot immutability, status, and
  native PDF sharing. Search for stale V2/V3/V4 migration claims, legacy policy
  names, unfinished markers, debug code, raw user-facing strings, unsafe casts,
  and duplicate financial logic.

- [ ] **Run the complete final gates serially, once.**

  Run each preflight before each command. If resource pressure rises, stop,
  terminate only stale test/build processes, shut down unused simulators, and
  report the deferred remainder. Do not repeat a successful full gate unless
  source changed afterward.

  1. iOS 18 unit/integration suite, with reopening reserved for step 5:

     ```bash
     xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS18_DESTINATION" \
       -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
       -only-testing:FarrierFlowTests \
       -skip-testing:FarrierFlowTests/PersistentStoreReopenTests
     ```

  2. iOS 26 unit/integration suite, with reopening reserved for step 5:

     ```bash
     xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS26_DESTINATION" \
       -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
       -only-testing:FarrierFlowTests \
       -skip-testing:FarrierFlowTests/PersistentStoreReopenTests
     ```

  3. Focused iOS 18 acceptance flow:

     ```bash
     xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS18_DESTINATION" \
       -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
       -only-testing:FarrierFlowUITests/InvoiceFlowUITests
     ```

  4. Full iOS 26 UI suite:

     ```bash
     xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS26_DESTINATION" \
       -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
       -only-testing:FarrierFlowUITests
     ```

  5. Persistent-reopening gate on iOS 18, then iOS 26:

     ```bash
     xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS18_DESTINATION" \
       -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
       -only-testing:FarrierFlowTests/PersistentStoreReopenTests

     xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS26_DESTINATION" \
       -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
       -only-testing:FarrierFlowTests/PersistentStoreReopenTests
     ```

     There is intentionally no migration gate because this is the first
     shipping schema.

  6. iOS 18 build:

     ```bash
     xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS18_DESTINATION"
     ```

  7. iOS 26 build:

     ```bash
     xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
       -destination "$IOS26_DESTINATION"
     ```

  8. Catalog and diff checks:

     ```bash
     plutil -lint FarrierFlow/Resources/Localizable.xcstrings
     git diff --check
     ```

- [ ] **Commit the integrated, verified Slice 5 polish.**

  ```bash
  git add -- FarrierFlow/Core/Persistence/PreviewFixtures.swift \
    FarrierFlow/App/UITestLaunchConfiguration.swift \
    FarrierFlow/Features/Clients/Views/ClientListView.swift \
    FarrierFlow/Features/Clients/Views/ClientDetailView.swift \
    FarrierFlow/Features/BusinessProfile/Views/BusinessProfileEditorView.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceCreationView.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceListView.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift \
    FarrierFlow/Features/Invoices/Views/InvoiceShareSheet.swift \
    FarrierFlow/Resources/Localizable.xcstrings \
    FarrierFlowUITests/InvoiceFlowUITests.swift \
    FarrierFlowUITests/RootNavigationUITests.swift \
    FarrierFlowUITests/EditorAccessibilityUITests.swift \
    FarrierFlowUITests/BlockedMutationUITests.swift \
    FarrierFlowUITests/FormatterDisplayUITests.swift \
    PRODUCT.md DESIGN.md ARCHITECTURE.md DATA_MODEL.md ROADMAP.md
  git diff --cached --check
  git diff --cached
  git commit -m "feat: finish Slice 5 invoicing"
  ```
