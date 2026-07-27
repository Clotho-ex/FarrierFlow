# Slice 2 — Visit Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `superpowers:test-driven-development` for every behavior change and
> `superpowers:verification-before-completion` before reporting the slice
> complete. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a migration-safe Visit workflow that starts from an existing
Appointment, records and persists an outcome for every scheduled Horse,
supports explicit progress saving and completion, and exposes completed work
from Horse History after process termination and store reopening.

**Architecture:** Preserve the existing SwiftUI view →
`@MainActor @Observable` feature model → focused domain rule/use case →
SwiftData boundary. Keep `FarrierFlowSchemaV1` immutable and add a complete V2
schema snapshot. Visit editors own drafts and a Visit-specific `ModelContext`
created from the environment `ModelContainer`; that context contains no
unrelated unsaved work, so a failed Visit transaction can be rolled back
without affecting another screen. Routes and presentations carry only
`PersistentIdentifier` values. No repository layer, dependency container,
event bus, or generalized autosave abstraction is introduced.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, Observation, SwiftData
versioned schemas and lightweight migration, OSLog, Swift Testing, XCTest UI
testing, iOS 18.0 minimum, latest stable iOS 26 SDK.

## Source of Truth

- `AGENTS.md`
- `PRODUCT.md`
- `DESIGN.md`
- `ARCHITECTURE.md`
- `DATA_MODEL.md`
- `ROADMAP.md`
- `docs/superpowers/specs/2026-07-27-slice-2-visit-completion-design.md`

If implementation evidence contradicts these documents, stop and report the
specific contradiction. Do not silently reinterpret or broaden the approved
design.

## Global Constraints

- Slice 0 and Slice 1 behavior remains frozen except for the approved V2
  migration, Visit relationships, Visit-aware delete rules, Appointment locks,
  and Horse relocation amendment.
- Keep every app and test target at iOS 18.0 and iPhone only. Do not modify
  deployment targets while implementing this plan.
- Use standard `TabView`, `NavigationStack`, `List`, `Form`, `Section`,
  toolbar, sheet, alert, confirmation-dialog, and `ContentUnavailableView`
  behavior. Add no tab and no custom navigation.
- Use standard controls so iOS 18 and iOS 26 supply their native appearance.
  Do not call custom Liquid Glass or iOS 26-only visual-effect APIs.
- Keep `FarrierFlowSchemaV1` model files byte-for-byte stable unless a migration
  test proves a genuine platform contradiction.
- Do not rename the production `ModelConfiguration` or change its store URL
  when switching the current schema to V2.
- Store only the approved Visit fields. Do not add persisted UUIDs, a Visit
  status property, general Visit notes, Horse or Client snapshots, ordering
  fields, service data, prices, photos, invoice data, or future workflow state.
- Required V2 to-one relationships are optional only in SwiftData storage.
  Controlled writes validate them as required, and reads never force-unwrap.
- Persisted Visit outcome raw values are not display copy. All visible statuses,
  labels, alerts, dates, and notes labels remain localization-ready in the
  English source catalog.
- Use `@State` for view-owned `@Observable` models, `@Bindable` only where
  bindings are needed, stable SwiftData identity in lists, and unary row
  content.
- Visit drafts are not autosaved on each change. Backgrounding makes one
  best-effort Save Progress attempt; no background task, external draft file,
  timer, debounce, networking, or cloud recovery is added.
- Run one simulator destination at a time. Reuse the installed iOS 18 and iOS
  26 simulators; never create or clone a simulator.
- Do not stage, commit, push, or open a pull request unless the user separately
  requests it.

---

## Complete File Map

### Documentation already updated before implementation

- `PRODUCT.md` — records the approved Slice 2 product capability and evidence.
- `DESIGN.md` — defines native Visit entry, editing, statuses, Horse History,
  locked Appointment fields, and Visit-aware relocation presentation.
- `ARCHITECTURE.md` — adds Visits ownership, V2 migration, validation
  boundaries, background-save limits, and test layers.
- `DATA_MODEL.md` — defines V2 fields, relationships, delete rules, optional
  storage, invariants, and migration behavior.
- `ROADMAP.md` — marks Slice 0/1 complete and authorizes the Slice 2 outcome,
  acceptance flow, and quality gates.

Do not revise those documents during implementation unless executable evidence
reveals a concrete contradiction.

### Files to create

#### V2 SwiftData snapshot

- `FarrierFlow/Core/Persistence/Schema/V2/FarrierFlowSchemaV2.swift`
- `FarrierFlow/Core/Persistence/Schema/V2/Client.swift`
- `FarrierFlow/Core/Persistence/Schema/V2/Barn.swift`
- `FarrierFlow/Core/Persistence/Schema/V2/Horse.swift`
- `FarrierFlow/Core/Persistence/Schema/V2/Appointment.swift`
- `FarrierFlow/Core/Persistence/Schema/V2/AppointmentHorse.swift`
- `FarrierFlow/Core/Persistence/Schema/V2/Visit.swift`
- `FarrierFlow/Core/Persistence/Schema/V2/VisitHorse.swift`

#### Visits feature

- `FarrierFlow/Features/Visits/Models/VisitOutcome.swift`
- `FarrierFlow/Features/Visits/Models/VisitDraft.swift`
- `FarrierFlow/Features/Visits/VisitRules.swift`
- `FarrierFlow/Features/Visits/VisitStartUseCase.swift`
- `FarrierFlow/Features/Visits/VisitSaveUseCase.swift`
- `FarrierFlow/Features/Visits/VisitDiscardUseCase.swift`
- `FarrierFlow/Features/Visits/VisitEditorModel.swift`
- `FarrierFlow/Features/Visits/VisitDetailModel.swift`
- `FarrierFlow/Features/Visits/VisitRoutes.swift`
- `FarrierFlow/Features/Visits/Views/VisitEditorView.swift`
- `FarrierFlow/Features/Visits/Views/VisitDetailView.swift`
- `FarrierFlow/Features/Visits/Components/VisitHorseOutcomeRow.swift`
- `FarrierFlow/Features/Visits/Components/VisitHorseResultRow.swift`

#### Horse History

- `FarrierFlow/Features/Horses/Models/HorseHistoryEntry.swift`
- `FarrierFlow/Features/Horses/HorseHistoryRules.swift`
- `FarrierFlow/Features/Horses/Components/HorseHistoryRow.swift`

#### Test support and coverage

- `FarrierFlowTests/Support/V1StoreFixture.swift`
- `FarrierFlowTests/Core/Persistence/SchemaMigrationTests.swift`
- `FarrierFlowTests/Features/Visits/VisitRulesTests.swift`
- `FarrierFlowTests/Features/Visits/VisitStartUseCaseTests.swift`
- `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`
- `FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift`
- `FarrierFlowTests/Features/Horses/HorseHistoryRulesTests.swift`
- `FarrierFlowUITests/VisitCompletionUITests.swift`

### Files to modify

#### Persistence and fixtures

- `FarrierFlow/Core/Persistence/Schema/CurrentSchema.swift`
- `FarrierFlow/Core/Persistence/Migrations/FarrierFlowMigrationPlan.swift`
- `FarrierFlow/Core/Persistence/ModelContainerFactory.swift`
- `FarrierFlow/Core/Persistence/PreviewFixtures.swift`
- `FarrierFlow/Core/Persistence/DomainGraphValidator.swift`
- `FarrierFlow/Core/Persistence/RecordDeletionRules.swift`

#### Appointment entry, locking, and status

- `FarrierFlow/Features/Schedule/AppointmentDetailModel.swift`
- `FarrierFlow/Features/Schedule/AppointmentEditorModel.swift`
- `FarrierFlow/Features/Schedule/Views/AppointmentDetailView.swift`
- `FarrierFlow/Features/Schedule/Views/AppointmentEditorView.swift`
- `FarrierFlow/Features/Schedule/Components/AppointmentRow.swift`

#### Visit-aware Horse behavior

- `FarrierFlow/Features/Horses/HorseRelocationRules.swift`
- `FarrierFlow/Features/Horses/HorseEditorModel.swift`
- `FarrierFlow/Features/Horses/Views/HorseEditorView.swift`
- `FarrierFlow/Features/Horses/HorseDetailModel.swift`
- `FarrierFlow/Features/Horses/Views/HorseDetailView.swift`
- `FarrierFlow/Features/Barns/ExistingHorsePickerModel.swift`
- `FarrierFlow/Features/Barns/Views/ExistingHorsePickerView.swift`

#### Resources and existing tests

- `FarrierFlow/Resources/Localizable.xcstrings`
- `FarrierFlowTests/Support/ModelFixtures.swift`
- `FarrierFlowTests/Core/Persistence/SchemaContractTests.swift`
- `FarrierFlowTests/Core/Persistence/ModelContainerFactoryTests.swift`
- `FarrierFlowTests/Core/Persistence/SwiftDataRelationshipInsertionTests.swift`
- `FarrierFlowTests/Core/Persistence/DomainGraphValidatorTests.swift`
- `FarrierFlowTests/Core/Persistence/RecordDeletionRulesTests.swift`
- `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`
- `FarrierFlowTests/Features/Horses/HorseDraftAndRelocationTests.swift`
- `FarrierFlowTests/Features/Schedule/AppointmentEditorModelTests.swift`

### Files intentionally not modified

- `FarrierFlow.xcodeproj/project.pbxproj` — synchronized groups discover the new
  files; deployment and device settings remain unchanged.
- `FarrierFlow/App/RootView.swift` — the three-tab information architecture is
  unchanged.
- `FarrierFlow/App/FarrierFlowApp.swift` — it continues to obtain its container
  from `ModelContainerFactory`.
- Existing V1 model files under `Core/Persistence/Schema/` — V1 remains the
  immutable prior schema snapshot.

---

## Task 1: Add failing V2 schema and migration contract tests

**Files:**

- Create: `FarrierFlowTests/Support/V1StoreFixture.swift`
- Create: `FarrierFlowTests/Core/Persistence/SchemaMigrationTests.swift`
- Modify: `FarrierFlowTests/Core/Persistence/SchemaContractTests.swift`
- Modify: `FarrierFlowTests/Core/Persistence/ModelContainerFactoryTests.swift`

**Interfaces:**

- `V1StoreFixture` creates a real V1 store without using the current V2 factory.
- Contract tests keep proving V1 contains exactly five models and separately
  require V2 to contain exactly seven.
- Migration tests open the exact V1 URL with the current migration plan and
  prove that no Visit data is fabricated.

- [ ] **Step 1: Write the V2 schema contract before adding V2**

Add assertions for:

```swift
Set(Schema(versionedSchema: FarrierFlowSchemaV2.self).entities.map(\.name))
    == [
        "Client", "Barn", "Horse", "Appointment", "AppointmentHorse",
        "Visit", "VisitHorse",
    ]
```

Also assert every new inverse and delete rule:

```swift
Appointment.visit             // deny, inverse Visit.appointment
Barn.visits                   // deny, inverse Visit.barn
Horse.visitHorses             // deny, inverse VisitHorse.horse
Visit.visitHorses             // cascade, inverse VisitHorse.visit
Visit.appointment             // nullable storage, nullify
Visit.barn                    // nullable storage, nullify
VisitHorse.visit              // nullable storage, nullify
VisitHorse.horse              // nullable storage, nullify
```

- [ ] **Step 2: Write the real-store migration regression**

The test must:

1. Create a temporary directory and store URL.
2. Create a V1-only container at that URL.
3. Insert two Clients, one Barn, two Horses, one Appointment, and two
   AppointmentHorse records.
4. Save, release every V1 object/context/container reference with
   `autoreleasepool`.
5. Open the same URL using `ModelContainerFactory.persistentStoreTest`.
6. Verify every V1 field, inverse, and count.
7. Verify Visit and VisitHorse counts are zero.
8. Verify the existing Appointment still has no Visit.

- [ ] **Step 3: Run the focused tests and record the expected red result**

Run on the existing iOS 18 simulator:

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0' \
  -only-testing:FarrierFlowTests/SchemaContractTests \
  -only-testing:FarrierFlowTests/SchemaMigrationTests
```

Expected: compilation fails because `FarrierFlowSchemaV2` and the new
relationships do not exist. This is the required red state.

- [ ] **Step 4: Do not change production code in this task**

Proceed only after the test accurately describes the approved V2 contract.

---

## Task 2: Implement the immutable V2 snapshot and lightweight migration

**Files:**

- Create all eight files under
  `FarrierFlow/Core/Persistence/Schema/V2/`
- Modify: `FarrierFlow/Core/Persistence/Schema/CurrentSchema.swift`
- Modify:
  `FarrierFlow/Core/Persistence/Migrations/FarrierFlowMigrationPlan.swift`
- Modify: `FarrierFlow/Core/Persistence/ModelContainerFactory.swift`

**Interfaces:**

```swift
nonisolated enum FarrierFlowSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            Client.self, Barn.self, Horse.self, Appointment.self,
            AppointmentHorse.self, Visit.self, VisitHorse.self,
        ]
    }
}
```

The V2 Visit declarations must preserve the approved annotations:

```swift
extension FarrierFlowSchemaV2 {
    @Model
    final class Visit {
        var startedAt: Date
        var completedAt: Date?
        var serviceLocationNameSnapshot: String
        var serviceLocationAddressSnapshot: String?
        var appointment: Appointment?
        var barn: Barn?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \VisitHorse.visit
        )
        var visitHorses: [VisitHorse] = []
    }

    @Model
    final class VisitHorse {
        var outcomeRawValue: String
        var workNotes: String?
        var visit: Visit?
        var horse: Horse?
    }
}
```

The existing-model additions are:

```swift
@Relationship(deleteRule: .deny, inverse: \Visit.appointment)
var visit: Visit?

@Relationship(deleteRule: .deny, inverse: \Visit.barn)
var visits: [Visit] = []

@Relationship(deleteRule: .deny, inverse: \VisitHorse.horse)
var visitHorses: [VisitHorse] = []
```

- [ ] **Step 1: Copy the complete V1 fields and annotations into V2**

Do not typealias V1 model classes into V2. A versioned schema is a complete
snapshot. Copy every approved V1 field, initializer default, inverse, and delete
rule, then add only the three approved inverse properties and two new models.

- [ ] **Step 2: Point current application aliases at V2**

`CurrentSchema.swift` must expose:

```swift
typealias Client = FarrierFlowSchemaV2.Client
typealias Barn = FarrierFlowSchemaV2.Barn
typealias Horse = FarrierFlowSchemaV2.Horse
typealias Appointment = FarrierFlowSchemaV2.Appointment
typealias AppointmentHorse = FarrierFlowSchemaV2.AppointmentHorse
typealias Visit = FarrierFlowSchemaV2.Visit
typealias VisitHorse = FarrierFlowSchemaV2.VisitHorse
```

- [ ] **Step 3: Register the lightweight migration**

```swift
static var schemas: [any VersionedSchema.Type] {
    [FarrierFlowSchemaV1.self, FarrierFlowSchemaV2.self]
}

static var stages: [MigrationStage] {
    [.lightweight(fromVersion: FarrierFlowSchemaV1.self,
                  toVersion: FarrierFlowSchemaV2.self)]
}
```

- [ ] **Step 4: Switch all factory variants to the V2 schema**

Production, preview, in-memory test, and persistent-store test containers use
`Schema(versionedSchema: FarrierFlowSchemaV2.self)`. Keep the production
configuration name `FarrierFlowV1` and its derived URL unchanged so this
upgrade opens the existing store rather than creating a parallel empty store.

- [ ] **Step 5: Run the iOS 18 migration gate first**

Run the Task 1 command again.

Expected: V1 contract, V2 contract, and V1-to-V2 real-store migration pass.

If migration fails on iOS 18, stop implementation and report the exact error.
Do not recreate the store, add a destructive migration, or continue to feature
work.

- [ ] **Step 6: Run the same gate on iOS 26**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:FarrierFlowTests/SchemaContractTests \
  -only-testing:FarrierFlowTests/SchemaMigrationTests
```

Expected: the same migration contract passes. Run this only after the iOS 18
destination has finished; do not boot both destinations for the same gate.

---

## Task 3: Define Visit outcomes, drafts, and pure validation rules

**Files:**

- Create: `FarrierFlow/Features/Visits/Models/VisitOutcome.swift`
- Create: `FarrierFlow/Features/Visits/Models/VisitDraft.swift`
- Create: `FarrierFlow/Features/Visits/VisitRules.swift`
- Create: `FarrierFlowTests/Features/Visits/VisitRulesTests.swift`

**Interfaces:**

```swift
nonisolated enum VisitOutcome: String, CaseIterable, Codable, Sendable {
    case pending
    case serviced
    case notServiced
}

struct VisitHorseDraft: Equatable, Identifiable {
    let id: PersistentIdentifier       // VisitHorse identity
    let horseID: PersistentIdentifier
    let horseName: String
    var outcome: VisitOutcome
    var workNotes: String
}

struct VisitDraft: Equatable {
    let visitID: PersistentIdentifier
    var horses: [VisitHorseDraft]
}
```

`VisitRules` is actor-neutral. It validates draft data and returns typed
violations rather than user-facing English:

```swift
nonisolated enum VisitDraftViolation: Error, Equatable {
    case unknownOutcome
    case duplicateHorse
    case workNotesRequireServicedOutcome
    case pendingOutcomePreventsCompletion
    case completionRequiresServicedHorse
}

nonisolated enum VisitRules {
    static func progressViolation(in draft: VisitDraft) -> VisitDraftViolation?
    static func completionViolation(in draft: VisitDraft) -> VisitDraftViolation?
    static func correctionViolation(in draft: VisitDraft) -> VisitDraftViolation?
}
```

- [ ] **Step 1: Write failing outcome and progress tests**

Cover raw-value decoding, unknown values, empty Work Notes normalization,
pending progress, mixed resolved progress, duplicate Horse identity, and notes
on pending/not-serviced outcomes.

- [ ] **Step 2: Write failing completion and correction tests**

Cover:

- all pending;
- a remaining pending outcome;
- all not serviced;
- at least one serviced;
- correction rejecting pending;
- correction retaining at least one serviced Horse;
- serviced-to-not-serviced transition requiring notes-clear confirmation;
- dirty state as exact draft inequality from the last saved snapshot.

- [ ] **Step 3: Implement the smallest pure types and rules**

Do not import SwiftUI into these files. Keep localization and presentation out
of the persisted raw enum.

- [ ] **Step 4: Run the focused tests on iOS 18**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0' \
  -only-testing:FarrierFlowTests/VisitRulesTests
```

Expected: every Visit draft rule passes.

---

## Task 4: Extend complete-graph validation and delete preflight

**Files:**

- Modify: `FarrierFlow/Core/Persistence/DomainGraphValidator.swift`
- Modify: `FarrierFlow/Core/Persistence/RecordDeletionRules.swift`
- Modify: `FarrierFlowTests/Core/Persistence/DomainGraphValidatorTests.swift`
- Modify: `FarrierFlowTests/Core/Persistence/RecordDeletionRulesTests.swift`
- Modify:
  `FarrierFlowTests/Core/Persistence/SwiftDataRelationshipInsertionTests.swift`
- Modify: `FarrierFlowTests/Support/ModelFixtures.swift`

**Interfaces:**

Add graph violations for:

```swift
case visitMissingAppointment
case visitMissingBarn
case visitHasNoHorse
case visitHorseMissingVisit
case visitHorseMissingHorse
case duplicateVisitHorseMembership
case visitMembershipMismatch
case visitLocationNameMissing
case inProgressVisitHasCompletionDate
case completedVisitHasPendingHorse
case completedVisitHasNoServicedHorse
case completionPredatesStart
case workNotesRequireServicedOutcome
case appointmentVisitMismatch
```

Extend deletion blocks for:

```swift
case appointmentHasVisit
case barnHasVisits
case horseHasVisits
case completedVisitCannotBeDeleted
```

Use associated reference flags or a small typed reference summary for combined
Barn and Horse blocks instead of multiplying every possible combination into a
separate case.

- [ ] **Step 1: Add failing valid-graph and invalid-graph tests**

`ModelFixtures.makeVisit` must create a valid Visit from an existing
Appointment and its exact Horse set. Tests then corrupt one invariant at a time
and expect the corresponding typed violation.

- [ ] **Step 2: Amend Appointment barn validation narrowly**

For each AppointmentHorse:

- no Visit → Horse must match Appointment Barn;
- in-progress Visit → Horse must match Appointment Barn;
- completed Visit → a later `Horse.currentBarn` mismatch is valid;
- missing Visit relationships or mismatched Visit membership → invalid.

Do not infer Visit state from `Appointment.startDate`.

- [ ] **Step 3: Add failing deletion ownership tests**

Prove:

- Appointment with any Visit is blocked;
- Barn with any Visit is blocked;
- Horse with any VisitHorse is blocked;
- discarding an in-progress Visit deletes only its VisitHorse records;
- deleting a VisitHorse never deletes Visit or Horse;
- no application rule permits completed Visit deletion;
- existing Client, AppointmentHorse, and no-Visit deletion behavior remains
  green.

- [ ] **Step 4: Implement the validator and preflight changes**

Fetch Visit and VisitHorse once in `validateAll`, group them by identity, and
avoid repeated context fetches inside loops. Continue to validate every
required optional-storage relationship before saving.

- [ ] **Step 5: Run focused persistence tests**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0' \
  -only-testing:FarrierFlowTests/DomainGraphValidatorTests \
  -only-testing:FarrierFlowTests/RecordDeletionRulesTests \
  -only-testing:FarrierFlowTests/SwiftDataRelationshipInsertionTests
```

Expected: V1 behavior and every V2 invariant/delete rule pass without an iOS 18
deletion crash.

---

## Task 5: Start Visit atomically from Appointment Detail

**Files:**

- Create: `FarrierFlow/Features/Visits/VisitStartUseCase.swift`
- Create: `FarrierFlow/Features/Visits/VisitRoutes.swift`
- Create: `FarrierFlowTests/Features/Visits/VisitStartUseCaseTests.swift`
- Modify: `FarrierFlow/Features/Schedule/AppointmentDetailModel.swift`
- Modify: `FarrierFlow/Features/Schedule/Views/AppointmentDetailView.swift`

**Interfaces:**

```swift
@MainActor
enum VisitStartUseCase {
    static func start(
        appointmentID: PersistentIdentifier,
        now: Date,
        in container: ModelContainer
    ) throws -> PersistentIdentifier
}

enum VisitPresentation: Identifiable {
    case editor(PersistentIdentifier)
    case detail(PersistentIdentifier)

    enum ID: Hashable {
        case editor(PersistentIdentifier)
        case detail(PersistentIdentifier)
    }

    var id: ID {
        switch self {
        case .editor(let id): .editor(id)
        case .detail(let id): .detail(id)
        }
    }
}
```

`VisitStartUseCase` creates its own action-owned `ModelContext`, resolves the
Appointment inside that context, validates before mutation, captures `now` and
the normalized Barn snapshots exactly once, inserts the complete Visit graph,
and saves once. Because that context owns every pending change, failure may
call `rollback()` safely.

- [ ] **Step 1: Write the successful-start regression**

Prove a two-Horse, two-Client Appointment produces:

- exactly one Visit;
- exactly two VisitHorse records;
- all outcomes `pending`;
- identical Horse membership sets;
- correct Appointment and Barn inverses;
- `startedAt` equal to the injected time;
- nil `completedAt`;
- immutable name/address snapshots copied from the Appointment Barn.

- [ ] **Step 2: Write all preflight failures**

Cover no Barn, no joins, missing Horse, duplicate Horse, Horse outside Barn,
missing Client/current Barn, existing Visit, and empty normalized Barn name.
Assert Visit and VisitHorse counts remain zero.

- [ ] **Step 3: Force save failure**

Introduce the smallest closure seam around the final validator/save call.
Assert rollback removes all inserted models and inverse changes, leaves the
Appointment graph unchanged, and a later unrelated save plus store reopening
still contains no partial Visit.

- [ ] **Step 4: Implement Appointment Detail state and action**

Appointment Detail renders exactly one contextual action:

- no Visit → Start Visit;
- `completedAt == nil` → Resume Visit;
- completed → View Visit.

Start success sets `VisitPresentation.editor(id)`. Failure keeps Appointment
Detail visible and presents a localized native alert. Do not report success
before the save returns.

- [ ] **Step 5: Run focused tests**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0' \
  -only-testing:FarrierFlowTests/VisitStartUseCaseTests
```

Expected: successful, rejected, and forced-failure start paths pass.

---

## Task 6: Implement in-progress draft loading and Save Progress

**Files:**

- Create: `FarrierFlow/Features/Visits/VisitSaveUseCase.swift`
- Create: `FarrierFlow/Features/Visits/VisitEditorModel.swift`
- Create: `FarrierFlow/Features/Visits/Components/VisitHorseOutcomeRow.swift`
- Create: `FarrierFlow/Features/Visits/Views/VisitEditorView.swift`
- Create: `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`

**Interfaces:**

```swift
nonisolated enum VisitEditorLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class VisitEditorModel {
    private(set) var loadState: VisitEditorLoadState
    private(set) var lastSavedDraft: VisitDraft?
    var draft: VisitDraft?
    var alert: FeatureAlert?

    var isDirty: Bool { draft != lastSavedDraft }
    var canSaveProgress: Bool {
        guard loadState == .loaded, let draft else { return false }
        return VisitRules.progressViolation(in: draft) == nil
    }
    var canComplete: Bool {
        guard loadState == .loaded, let draft else { return false }
        return VisitRules.completionViolation(in: draft) == nil
    }
}
```

The model creates and retains one Visit-owned `ModelContext` from the supplied
container. It never places draft keystrokes into SwiftData. `VisitSaveUseCase`
applies the current draft only at the final persistence boundary.

- [ ] **Step 1: Write load-state tests**

Cover loading, successful data, legitimate empty impossibility as unavailable,
unknown outcome, missing relationship, fetch failure with Retry, and
preservation of a previously loaded draft after a failed reload.

- [ ] **Step 2: Write dirty-state and notes-transition tests**

Prove:

- loading produces equal draft/baseline;
- outcome or notes changes become dirty;
- Save Progress success updates the baseline;
- Discard Unsaved Changes restores the baseline;
- moving a serviced Horse with Work Notes to another outcome requires
  confirmation before clearing notes.

- [ ] **Step 3: Write Save Progress persistence tests**

Cover pending outcomes, mixed outcomes, notes normalization, invalid notes,
relationship mismatch, and forced save failure. On failure:

- the draft remains unchanged and dirty;
- persisted Visit remains in progress;
- persisted outcomes remain at the prior successful values;
- a later unrelated save cannot leak failed values.

- [ ] **Step 4: Implement the native editor**

Use `Form` with one `Section` per Horse or a single Horses section containing
`VisitHorseOutcomeRow`. Use a standard `Picker` or native selection control for
Pending, Serviced, and Not Serviced. Show Work Notes only for Serviced, with a
visible `"Work Notes"` label and explicit VoiceOver label.

The toolbar contains:

- Cancel;
- Save Progress;
- Complete Visit.

Show a localized unsaved-state indication when `isDirty`. Keep actions at least
44 points and allow labels/metadata to wrap under Dynamic Type.

- [ ] **Step 5: Implement dirty dismissal behavior**

Use `.interactiveDismissDisabled(model.isDirty)` so a swipe never silently
discards. Cancel prompts when dirty:

- Keep Editing;
- Discard Unsaved Changes and dismiss.

Discard Visit remains a separate destructive flow added in Task 7.

- [ ] **Step 6: Run focused tests**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0' \
  -only-testing:FarrierFlowTests/VisitEditorModelTests
```

Expected: load, dirty, notes, progress-save, retry, and forced-failure paths
pass.

---

## Task 7: Add completion, correction, discard, and background save

**Files:**

- Create: `FarrierFlow/Features/Visits/VisitDiscardUseCase.swift`
- Create: `FarrierFlow/Features/Visits/VisitDetailModel.swift`
- Create: `FarrierFlow/Features/Visits/Components/VisitHorseResultRow.swift`
- Create: `FarrierFlow/Features/Visits/Views/VisitDetailView.swift`
- Create: `FarrierFlowTests/Features/Visits/VisitDetailModelTests.swift`
- Modify: `FarrierFlow/Features/Visits/VisitEditorModel.swift`
- Modify: `FarrierFlow/Features/Visits/Views/VisitEditorView.swift`
- Modify: `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`

**Interfaces:**

```swift
enum VisitEditorMode: Equatable {
    case inProgress
    case correction
}

@MainActor
enum VisitDiscardUseCase {
    static func discard(
        visitID: PersistentIdentifier,
        in context: ModelContext
    ) throws
}
```

- [ ] **Step 1: Write failing completion tests**

Prove completion rejects pending outcomes, all-not-serviced outcomes, invalid
relationships, notes on non-serviced Horses, and a completion time before
`startedAt`. Success persists the draft and `completedAt` as one save.

Force the final save to fail and prove:

- `completedAt` returns to nil;
- persisted outcomes remain at their prior values;
- the draft stays dirty and recoverable;
- completion is not reported.

- [ ] **Step 2: Write completed-correction tests**

Correction may change only serviced/not-serviced outcomes and serviced Work
Notes. It must reject pending, preserve at least one serviced Horse, and leave
Appointment, Barn, membership, `startedAt`, `completedAt`, and both snapshots
unchanged after save and reopening.

- [ ] **Step 3: Write discard tests**

An in-progress Visit may be discarded only after confirmation. Prove the
cascade removes VisitHorse records and preserves Appointment,
AppointmentHorse, Barn, Horse, and Client. A completed Visit returns
`completedVisitCannotBeDeleted`.

- [ ] **Step 4: Implement Visit Detail and correction entry**

Visit Detail displays:

- localized `startedAt` work date;
- immutable service-location name and optional address snapshots;
- In Progress or Completed;
- every Horse outcome;
- Work Notes only when present.

If `Visit.barn` resolves, show a standard navigation affordance to
`BarnDetailView`. If it does not, keep the snapshots readable and omit the
affordance. A completed Visit exposes Edit; an in-progress Visit exposes Resume.
No completed delete action exists.

`VisitDetailModelTests` cover a complete record, invalid/missing VisitHorse
relationships, unknown outcome, fetch failure with Retry, and a missing Barn
relationship that still exposes both immutable snapshots.

- [ ] **Step 5: Implement best-effort scene-background saving**

`VisitEditorView` observes `scenePhase`. When it becomes `.background` and the
in-progress draft is dirty, call the same `saveProgress` method. Do not create a
Task with extended execution, a timer, or a background task.

If the same process becomes active after failure, preserve the draft and show
the pending localized error. If the process is terminated, no in-memory draft
or error is promised; the next load reads the last successful SwiftData save.

- [ ] **Step 6: Run the focused Visit suite**

Run `VisitRulesTests`, `VisitStartUseCaseTests`, and `VisitEditorModelTests`
together on iOS 18. Expected: start, progress, completion, correction, discard,
and background-boundary tests pass.

---

## Task 8: Lock Appointment membership and expose Visit status

**Files:**

- Modify: `FarrierFlow/Features/Schedule/AppointmentEditorModel.swift`
- Modify: `FarrierFlow/Features/Schedule/Views/AppointmentEditorView.swift`
- Modify: `FarrierFlow/Features/Schedule/AppointmentDetailModel.swift`
- Modify: `FarrierFlow/Features/Schedule/Views/AppointmentDetailView.swift`
- Modify: `FarrierFlow/Features/Schedule/Components/AppointmentRow.swift`
- Modify:
  `FarrierFlowTests/Features/Schedule/AppointmentEditorModelTests.swift`
- Modify: `FarrierFlowTests/Core/Persistence/RecordDeletionRulesTests.swift`

**Interfaces:**

`AppointmentEditorModel` exposes immutable edit context:

```swift
private(set) var hasVisit: Bool
private(set) var lockedBarnName: String?
private(set) var lockedHorseNames: [String]
```

- [ ] **Step 1: Write locked-edit tests**

For an Appointment with a Visit, prove:

- Barn and selected Horse IDs load but cannot change;
- a forged draft Barn or membership change is rejected before mutation;
- scheduled start, notes, and expected duration save successfully;
- editable changes do not alter Visit timestamps, snapshots, or VisitHorse
  membership.

- [ ] **Step 2: Implement locked native form presentation**

When `hasVisit`:

- replace the Barn Picker with labeled read-only content;
- replace selectable Horse rows with a read-only Horse list;
- keep DatePicker, Appointment Notes, and expected-duration field enabled.

Do not merely disable opaque controls without explanation. Add concise
localized supporting text that the service location and Horses are fixed after
work starts.

- [ ] **Step 3: Block Appointment deletion**

`AppointmentDetailModel.delete` surfaces the typed
`RecordDeletionBlock.appointmentHasVisit` alert. It does not clear the detail
model before preflight succeeds.

- [ ] **Step 4: Add row status**

`AppointmentRow` adds one secondary localized status only when a Visit exists:

- `completedAt == nil` → In Progress;
- nonnil → Completed.

Keep scheduled time, current Appointment Barn, and Horse names as the primary
row content. Do not add a badge container or custom card.

- [ ] **Step 5: Run focused Appointment tests**

Expected: no-Visit editing/deletion behavior stays green, Visit locking passes,
and Visit timestamp/snapshot immutability is proven.

---

## Task 9: Replace relocation with the approved Visit-aware rule

**Files:**

- Modify: `FarrierFlow/Features/Horses/HorseRelocationRules.swift`
- Modify: `FarrierFlow/Features/Horses/HorseEditorModel.swift`
- Modify: `FarrierFlow/Features/Horses/Views/HorseEditorView.swift`
- Modify: `FarrierFlow/Features/Barns/ExistingHorsePickerModel.swift`
- Modify: `FarrierFlow/Features/Barns/Views/ExistingHorsePickerView.swift`
- Modify:
  `FarrierFlowTests/Features/Horses/HorseDraftAndRelocationTests.swift`

**Interfaces:**

Use a pure state projection rather than passing model collections into the
rule:

```swift
nonisolated enum AppointmentVisitState: Equatable, Sendable {
    case noVisit
    case inProgress
    case completed
    case invalid
}

static func canRelocate(
    appointmentStates: [AppointmentVisitState],
    hasInProgressVisitHorse: Bool,
    isSameBarn: Bool
) -> Bool
```

- [ ] **Step 1: Write the full relocation matrix**

Cover:

- no-op to the same Barn;
- no Appointment memberships;
- Appointment with no Visit, including past start date;
- in-progress Visit;
- completed Visit;
- mixed completed and unresolved Appointments;
- missing Appointment/Visit relationship;
- independently encountered in-progress VisitHorse.

- [ ] **Step 2: Update both mutation entry points**

`HorseEditorModel` and `ExistingHorsePickerModel` must derive the same state
projection and call the same rule. Add Existing Horse lists only Horses that
pass it and are not already at the destination.

- [ ] **Step 3: Preserve failed-relocation rollback evidence**

Extend the existing persistent-store regression:

1. Complete one Visit and prove its Appointment no longer blocks.
2. Add another unresolved Appointment and prove relocation remains blocked.
3. Remove that unresolved Appointment or complete its Visit.
4. Force persistence failure during an otherwise eligible relocation.
5. Prove the Horse remains at Barn A in memory.
6. Perform a later unrelated save.
7. Reopen and prove the Horse is still at Barn A.
8. Prove no Appointment, AppointmentHorse, Visit, VisitHorse, timestamp, or
   snapshot changed.

- [ ] **Step 4: Update copy**

Blocked alerts and the picker empty state explain unresolved or in-progress
appointments, not merely “any appointment.” Keep the copy localized and
concise.

- [ ] **Step 5: Run focused relocation tests**

Expected: the full matrix and the failed-save reopening regression pass on iOS
18.

---

## Task 10: Add completed Horse History and shared Visit Detail navigation

**Files:**

- Create: `FarrierFlow/Features/Horses/Models/HorseHistoryEntry.swift`
- Create: `FarrierFlow/Features/Horses/HorseHistoryRules.swift`
- Create: `FarrierFlow/Features/Horses/Components/HorseHistoryRow.swift`
- Create:
  `FarrierFlowTests/Features/Horses/HorseHistoryRulesTests.swift`
- Modify: `FarrierFlow/Features/Horses/HorseDetailModel.swift`
- Modify: `FarrierFlow/Features/Horses/Views/HorseDetailView.swift`

**Interfaces:**

```swift
struct HorseHistoryEntry: Identifiable, Equatable {
    let id: PersistentIdentifier       // VisitHorse identity
    let visitID: PersistentIdentifier
    let horseName: String
    let startedAt: Date
    let completedAt: Date
    let serviceLocationName: String
    let outcome: VisitOutcome
    let hasWorkNotes: Bool
}

nonisolated enum HorseHistoryLoadState: Equatable {
    case loading
    case loaded
    case failed
}
```

- [ ] **Step 1: Write filtering and exact-order tests**

Exclude in-progress Visits. Include both Serviced and Not Serviced completed
memberships. Sort by:

1. `startedAt` descending;
2. `completedAt` descending;
3. service-location snapshot ascending with localized comparison;
4. Horse name ascending with localized comparison.

Construct explicit ties for all four levels. Add no persisted tie-break field.

- [ ] **Step 2: Write load-state and invalid-data tests**

Cover loading, legitimate empty history, successful history, fetch failure with
Retry while retaining prior rows, missing Visit/Horse, unknown outcome, and
missing current Barn with readable snapshots.

- [ ] **Step 3: Implement Horse Detail history**

Add a `"History"` section. Empty history uses `ContentUnavailableView` with one
concise explanation. Each plain list row shows work date, immutable location
name, localized outcome, and a Work Notes indication when present.

Selecting a row navigates to the shared `VisitDetailView` using `visitID`.
History never derives a label from `Visit.barn`.

- [ ] **Step 4: Run focused history tests**

Expected: filter, four-level ordering, state preservation, and invalid-data
handling pass.

---

## Task 11: Localize, preview, and accessibility-check the Slice 2 UI

**Files:**

- Modify: `FarrierFlow/Resources/Localizable.xcstrings`
- Modify: `FarrierFlow/Core/Persistence/PreviewFixtures.swift`
- Modify all new Slice 2 views and rows as needed
- Create: `FarrierFlowUITests/VisitCompletionUITests.swift`

**Requirements:**

- English remains the only declared app localization.
- The catalog includes localization-ready entries for Pending, Serviced, Not
  Serviced, In Progress, Completed, Start Visit, Resume Visit, View Visit, Save
  Progress, Complete Visit, Discard Visit, Discard Unsaved Changes, Work Notes,
  unsaved state, unavailable states, blocked actions, and retry actions.
- Dates use environment locale/calendar/time zone and `FormatStyle`.
- Persisted raw values and manually concatenated unit strings never reach UI.

- [ ] **Step 1: Add populated and edge-state previews**

Seed or construct preview-only examples for:

- pending multi-Horse Visit;
- partially saved Visit;
- completed Visit with serviced and not-serviced Horses;
- Horse History populated and empty;
- missing Barn relationship with readable snapshots;
- accessibility Dynamic Type and Dark Mode.

Do not put synthetic data into production startup.

- [ ] **Step 2: Add stable accessibility identifiers for UI acceptance**

Identifiers must describe actions/records, not layout position. Cover start,
outcome selection, Work Notes, Save Progress, completion, Visit status, Horse
History row, and Visit Detail snapshot.

- [ ] **Step 3: Verify the accessibility hierarchy**

Using UI assertions and simulator inspection, confirm:

- every outcome control announces Horse name, outcome, and selected state;
- Work Notes has visible and VoiceOver labels;
- status is text, not color-only;
- rows form coherent accessibility elements;
- primary actions remain reachable at accessibility text sizes;
- Reduce Motion introduces no dependency on animation.

- [ ] **Step 4: Inspect the string catalog**

Run:

```bash
rg -n '"(tr|Turkish)"|developmentRegion|knownRegions' \
  FarrierFlow/Resources/Localizable.xcstrings \
  FarrierFlow.xcodeproj/project.pbxproj
```

Expected: English source strings only, no actual Turkish translation or Turkish
declared localization. Turkish-locale formatter tests remain valid and are not
removed.

---

## Task 12: Prove migration, reopening, and the exact UI acceptance flow

**Files:**

- Modify: `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`
- Modify: `FarrierFlowTests/Core/Persistence/ModelContainerFactoryTests.swift`
- Modify: `FarrierFlowUITests/VisitCompletionUITests.swift`

- [ ] **Step 1: Add all reopening scenarios**

Using real temporary stores and complete release/reopen boundaries, prove:

- Start Visit reopens with every membership pending.
- Save partial progress reopens with the last saved outcomes and notes.
- Unsaved draft changes disappear after simulated process recreation.
- Completed Visit reopens with timestamps, snapshots, outcomes, notes, and
  every inverse.
- Completed correction reopens with timestamps and snapshots unchanged.
- Relocation after completion reopens with the new `Horse.currentBarn` and the
  original immutable Visit snapshots.
- Discarded in-progress Visit remains absent while Appointment and joins remain.
- Delete preflight remains correct after reopening.

- [ ] **Step 2: Extend the V1 migration path through completed history**

After migrating a V1 graph:

1. prove zero fabricated Visits;
2. start a Visit;
3. save progress;
4. complete it;
5. release and reopen V2;
6. verify the complete historical graph.

- [ ] **Step 3: Automate the exact Slice 2 flow on iOS 26**

The UI test reuses a unique persistent UI-test store:

1. create or open the frozen Slice 1 connected graph;
2. open Appointment Detail;
3. Start Visit;
4. verify every Horse Pending;
5. mark at least one Serviced and remaining Horses explicitly;
6. enter Work Notes;
7. Save Progress;
8. terminate and relaunch;
9. verify in-progress values;
10. Complete Visit;
11. view Visit Detail;
12. open the same Visit from Horse History;
13. terminate and relaunch;
14. verify the completed historical record and immutable snapshots.

- [ ] **Step 4: Add focused UI rule coverage**

Within the same test file, cover:

- incomplete outcome blocks completion;
- all Not Serviced blocks completion;
- dirty dismissal confirmation;
- in-progress discard confirmation;
- Appointment delete blocked after start;
- relocation blocked before completion and allowed after;
- editing scheduled start does not change history date;
- missing Barn snapshot fallback using test-only launch fixture if feasible
  without weakening production validation.

---

## Task 13: Run sequential platform gates and inspect the final diff

No simulator is created or cloned. If the named installed destination has
changed, resolve the corresponding existing iOS 18/iOS 26 device with
`xcrun simctl list devices available`; do not call `simctl create` or Xcode
device cloning.

- [ ] **Step 1: Run all unit and integration tests on iOS 18**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0' \
  -only-testing:FarrierFlowTests
```

Expected: all unit, SwiftData, migration, deletion, relocation, and reopening
tests pass.

- [ ] **Step 2: Build on iOS 18 and inspect diagnostics**

```bash
xcodebuild build \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0'
```

Expected: build succeeds with zero project warnings or errors.

- [ ] **Step 3: Shut down or stop using the iOS 18 destination before the iOS
26 gate**

Keep at most one simulator actively running to respect the 16 GB RAM limit.

- [ ] **Step 4: Run all unit and integration tests on iOS 26**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:FarrierFlowTests
```

Expected: all tests pass.

- [ ] **Step 5: Run the complete UI suite on iOS 26**

```bash
xcodebuild test \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:FarrierFlowUITests
```

Expected: existing Slice 0/1 UI tests and the complete Slice 2 acceptance suite
pass.

- [ ] **Step 6: Build on iOS 26 and inspect diagnostics**

```bash
xcodebuild build \
  -project FarrierFlow.xcodeproj \
  -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: build succeeds with zero project warnings or errors.

- [ ] **Step 7: Perform focused manual accessibility and appearance checks**

On the existing iOS 26 simulator, inspect the Visit editor, Visit Detail, and
Horse History in:

- Light Mode;
- Dark Mode;
- an accessibility Dynamic Type size;
- Increased Contrast;
- Reduce Motion;
- VoiceOver hierarchy.

Repeat the core Start → Save Progress → Complete behavior once on iOS 18 after
the iOS 26 run finishes.

- [ ] **Step 8: Verify target and localization settings did not drift**

```bash
xcodebuild -project FarrierFlow.xcodeproj -scheme FarrierFlow \
  -showBuildSettings |
  rg 'IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY'
```

Expected: app, unit-test, and UI-test targets retain iOS 18.0, iPhone-only, and
Swift 6 strict concurrency settings.

- [ ] **Step 9: Inspect scope and diff hygiene**

```bash
git diff --check
git status --short
git diff --stat
rg --files FarrierFlow/Features |
  rg 'Visits|Photos|Invoices|Money|PDF|Notifications|Settings'
```

Expected:

- `git diff --check` passes;
- only planned documentation, Visit, persistence, Schedule, Horse, Barn,
  resource, and test files changed;
- Visits is the only newly active feature directory;
- no deferred feature directory, screen, model, service, or abstraction exists;
- no debug output, generated result bundle, temporary store, or credential is
  present.

- [ ] **Step 10: Review the complete diff before reporting**

Confirm:

- V1 model files are unchanged;
- production store identity is unchanged;
- every V2 relationship annotation matches `DATA_MODEL.md`;
- no controlled write force-unwraps relationships;
- failure paths do not leave pending persistence mutations;
- no completed Visit delete path exists;
- no time-based Appointment resolution exists;
- all user-facing Slice 2 strings are localized;
- no iOS 26-only essential behavior exists.

---

## Completion Report

Before claiming Slice 2 complete, report:

- every file created and modified;
- the original red migration/schema test result;
- the passing iOS 18 unit/integration count;
- the passing iOS 26 unit/integration count;
- the passing iOS 26 UI count;
- the focused iOS 18 workflow result;
- V1-to-V2 migration and no-fabrication evidence;
- all reopening scenario results;
- deletion, relocation, correction, and rollback results;
- accessibility and localization verification;
- both build diagnostic results;
- `git diff --check` and working-tree state;
- any remaining warning, platform limitation, or risk.

Do not begin Slice 3. Do not stage or commit the implementation until the user
has reviewed the verification report and explicitly asks for Git actions.
