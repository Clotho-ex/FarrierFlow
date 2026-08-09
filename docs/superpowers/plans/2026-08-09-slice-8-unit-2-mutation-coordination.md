# Slice 8 Unit 2 Mutation Coordination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the full-owner export snapshot reject material production SwiftData writes that overlap cooperative snapshot construction, including writes whose final pending state returns to its baseline.

**Architecture:** `AppDependencies` owns one main-actor `PersistenceMutationCoordinator` beside the shared `ModelContainer` and injects it explicitly into production writers and export. Writers enter a scoped mutation generation before their first model change and retain it through save, rollback, and operation-owned suspension points. Export captures a quiescent read generation and performs constant-time checks at cooperative boundaries; it never blocks writers or rescans the graph to prove atomicity.

**Tech Stack:** Swift 6, SwiftUI environment, SwiftData, Swift Testing, iOS 18 deployment target, iOS 26 SDK, no third-party dependencies.

## Global Constraints

- Preserve the existing 14-entity SwiftData schema; add no model, field, migration, or persisted export history.
- Keep `ModelContext`, SwiftData models, and the coordinator main-actor isolated.
- The coordinator is app-composition-owned, not a singleton, service locator, repository, notification bus, or write lock.
- Writers remain available during export. A concurrent writer invalidates export at the next safe boundary.
- Production operations enter the write scope before their first SwiftData mutation and retain it through save or rollback.
- Constant-time generation checks may not synchronously scan changed, inserted, deleted, or fetched model collections.
- Existing app-owned record iteration remains bounded to at most 200 records between cooperative yields.
- Preview and test fixture seeding completed before export does not require production coordination.
- Use one iOS 26 simulator, disabled parallel testing, and one test worker for focused verification.
- Do not start Unit 3, add Export UI/filesystem behavior, change the V1 archive contract, or push.

---

### Task 1: Add the app-owned mutation generation primitive

**Files:**
- Create: `FarrierFlow/Core/Persistence/PersistenceMutationCoordinator.swift`
- Create: `FarrierFlowTests/Core/Persistence/PersistenceMutationCoordinatorTests.swift`

**Interfaces:**
- Produces: `@MainActor final class PersistenceMutationCoordinator`.
- Produces: `PersistenceMutationCoordinator.ReadGeneration`, an opaque equality-only value.
- Produces: `beginRead() throws -> ReadGeneration` and `validate(_:) throws`.
- Produces: synchronous and asynchronous `withMutation` overloads that retain active-writer state for the complete closure lifetime.
- Produces: `PersistenceMutationCoordinatorError.writerActive` and `.sourceChanged`.

- [ ] **Step 1: Write focused behavior tests before production code**

Add tests using the real coordinator:

```swift
@MainActor
@Test func rejectsReadWhileWriterIsActive() async throws {
    let coordinator = PersistenceMutationCoordinator()
    let gate = AsyncTestGate()
    let writer = Task { @MainActor in
        try await coordinator.withMutation {
            await gate.signalStartedAndWait()
        }
    }
    await gate.waitUntilStarted()

    #expect(throws: PersistenceMutationCoordinatorError.writerActive) {
        _ = try coordinator.beginRead()
    }
    gate.release()
    try await writer.value
}

@MainActor
@Test func invalidatesReadWhenWriterStartsAndFinishesBetweenChecks() throws {
    let coordinator = PersistenceMutationCoordinator()
    let generation = try coordinator.beginRead()

    coordinator.withMutation {}

    #expect(throws: PersistenceMutationCoordinatorError.sourceChanged) {
        try coordinator.validate(generation)
    }
}
```

Also cover a stable read remaining valid and an asynchronous writer retaining active state across a suspension. Keep the async gate in test support or the test file; add no test-only production method.

- [ ] **Step 2: Run RED and confirm the missing coordinator is the failure**

Run:

```bash
xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,id=A9501C1D-4747-4310-8F2B-F0587E0E30C6' \
  -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
  -only-testing:FarrierFlowTests/PersistenceMutationCoordinatorTests
```

Expected: compile failure because `PersistenceMutationCoordinator` and its errors do not exist.

- [ ] **Step 3: Implement the minimal constant-time coordinator**

Use an opaque token that changes at both write entry and exit:

```swift
import Foundation

nonisolated enum PersistenceMutationCoordinatorError: Error, Equatable {
    case writerActive
    case sourceChanged
}

@MainActor
final class PersistenceMutationCoordinator {
    nonisolated struct ReadGeneration: Equatable, Sendable {
        fileprivate let token: UUID
    }

    private var token = UUID()
    private var activeWriterCount = 0

    func beginRead() throws -> ReadGeneration {
        guard activeWriterCount == 0 else {
            throw PersistenceMutationCoordinatorError.writerActive
        }
        return ReadGeneration(token: token)
    }

    func validate(_ generation: ReadGeneration) throws {
        guard activeWriterCount == 0 else {
            throw PersistenceMutationCoordinatorError.writerActive
        }
        guard generation.token == token else {
            throw PersistenceMutationCoordinatorError.sourceChanged
        }
    }

    func withMutation<Value>(_ body: () throws -> Value) rethrows -> Value {
        beginMutation()
        defer { endMutation() }
        return try body()
    }

    func withMutation<Value>(_ body: () async throws -> Value) async rethrows -> Value {
        beginMutation()
        defer { endMutation() }
        return try await body()
    }

    private func beginMutation() {
        activeWriterCount += 1
        token = UUID()
    }

    private func endMutation() {
        activeWriterCount -= 1
        token = UUID()
    }
}
```

Nested app-owned scopes remain valid because the active-writer count is balanced; no production path depends on nesting to supply correctness.

- [ ] **Step 4: Run GREEN**

Run the Task 1 selector and require all coordinator tests to pass.

- [ ] **Step 5: Audit and commit Task 1**

Run `git diff --check`, inspect only the two Task 1 files, then commit:

```bash
git add FarrierFlow/Core/Persistence/PersistenceMutationCoordinator.swift \
  FarrierFlowTests/Core/Persistence/PersistenceMutationCoordinatorTests.swift
git commit -m "feat(persistence): track coordinated mutations"
```

---

### Task 2: Put every ordinary production CRUD writer inside an explicit scope

**Files:**
- Modify: `FarrierFlow/App/FarrierFlowApp.swift`
- Modify: `FarrierFlow/Features/Barns/BarnEditorModel.swift`
- Modify: `FarrierFlow/Features/Barns/BarnDetailModel.swift`
- Modify: `FarrierFlow/Features/Barns/ExistingHorsePickerModel.swift`
- Modify: `FarrierFlow/Features/BusinessProfile/BusinessProfileEditorModel.swift`
- Modify: `FarrierFlow/Features/Clients/ClientEditorModel.swift`
- Modify: `FarrierFlow/Features/Clients/ClientDetailModel.swift`
- Modify: `FarrierFlow/Features/Horses/HorseEditorModel.swift`
- Modify: `FarrierFlow/Features/Horses/HorseDetailModel.swift`
- Modify: `FarrierFlow/Features/Schedule/AppointmentEditorModel.swift`
- Modify: `FarrierFlow/Features/Schedule/AppointmentDetailModel.swift`
- Modify: `FarrierFlow/Features/Services/ServiceEditorModel.swift`
- Modify: `FarrierFlow/Features/Services/ServiceDetailModel.swift`
- Modify: `FarrierFlow/Features/Barns/Views/BarnEditorView.swift`
- Modify: `FarrierFlow/Features/Barns/Views/BarnDetailView.swift`
- Modify: `FarrierFlow/Features/Barns/Views/ExistingHorsePickerView.swift`
- Modify: `FarrierFlow/Features/BusinessProfile/Views/BusinessProfileEditorView.swift`
- Modify: `FarrierFlow/Features/Clients/Views/ClientEditorView.swift`
- Modify: `FarrierFlow/Features/Clients/Views/ClientDetailView.swift`
- Modify: `FarrierFlow/Features/Horses/Views/HorseEditorView.swift`
- Modify: `FarrierFlow/Features/Horses/Views/HorseDetailView.swift`
- Modify: `FarrierFlow/Features/Schedule/Views/AppointmentEditorView.swift`
- Modify: `FarrierFlow/Features/Schedule/Views/AppointmentDetailView.swift`
- Modify: `FarrierFlow/Features/Services/Views/ServiceEditorView.swift`
- Modify: `FarrierFlow/Features/Services/Views/ServiceDetailView.swift`
- Test: `FarrierFlowTests/Features/Barns/BarnDraftAndModelTests.swift`
- Test: `FarrierFlowTests/Features/BusinessProfile/BusinessProfileEditorModelTests.swift`
- Test: `FarrierFlowTests/Features/Clients/ClientDraftAndModelTests.swift`
- Test: `FarrierFlowTests/Features/Horses/HorseDetailModelTests.swift`
- Test: `FarrierFlowTests/Features/Horses/HorseDraftAndRelocationTests.swift`
- Test: `FarrierFlowTests/Features/Horses/HorseEditorModelTests.swift`
- Test: `FarrierFlowTests/Features/Schedule/AppointmentDetailModelTests.swift`
- Test: `FarrierFlowTests/Features/Schedule/AppointmentEditorModelTests.swift`
- Test: `FarrierFlowTests/Features/Services/ServiceDetailModelTests.swift`
- Test: `FarrierFlowTests/Features/Services/ServiceEditorModelTests.swift`
- Test: `FarrierFlowTests/Core/Persistence/RecordDeletionRulesTests.swift`

**Interfaces:**
- Consumes: `PersistenceMutationCoordinator.withMutation` from Task 1.
- Produces: one `PersistenceMutationCoordinator` in `AppDependencies`, injected with `.environment(...)` beside `PhotographLibrary`.
- Produces: mutating model methods with an explicit `coordinator:` argument; read-only load methods remain unchanged.

- [ ] **Step 1: Add RED assertions to representative create, update, delete, and relocation tests**

For one representative of each behavior, begin a read generation before invoking the real model method with a coordinator, then require `validate` to throw `.sourceChanged` after success. Include failed-save coverage proving the generation changes even when the context rolls back.

```swift
let coordinator = PersistenceMutationCoordinator()
let generation = try coordinator.beginRead()
let savedID = model.save(in: context, coordinator: coordinator)
#expect(savedID != nil)
#expect(throws: PersistenceMutationCoordinatorError.sourceChanged) {
    try coordinator.validate(generation)
}
```

Required representative suites: Service create/update, Appointment save, Horse relocation, and Client or Barn deletion.

- [ ] **Step 2: Run the representative selectors and verify RED**

Run one serial command selecting only the changed suites. Expected: compile failures because the mutating APIs do not accept a coordinator and app composition does not inject it.

- [ ] **Step 3: Add app composition and wrap ordinary writers**

Create the coordinator before feature dependencies:

```swift
let mutationCoordinator = PersistenceMutationCoordinator()
return AppDependencies(
    container: container,
    mutationCoordinator: mutationCoordinator,
    photographLibrary: PhotographLibrary(
        container: container,
        mutationCoordinator: mutationCoordinator,
        fileStore: fileStore
    )
)
```

At the root, inject `.environment(dependencies.mutationCoordinator)`. Each mutating view reads that environment value and passes it to the model method. Wrap the complete mutate/validate/save/rollback sequence, not just `context.save()`:

```swift
func save(
    in context: ModelContext,
    coordinator: PersistenceMutationCoordinator
) -> PersistentIdentifier? {
    coordinator.withMutation {
        // Existing resolution, insert/update, DomainGraphValidator.save,
        // rollback, alert, and return behavior stays inside this closure.
    }
}
```

Do not wrap draft editing because drafts are immutable/plain Swift values and do not mutate SwiftData. Keep preview/test seeding unchanged because it completes before app dependencies expose export.

- [ ] **Step 4: Run GREEN for the ordinary writer suites**

Run the representative RED selectors, then all directly changed editor/detail model suites in one serial command. Require the original behavior plus generation invalidation to pass.

- [ ] **Step 5: Audit and commit Task 2**

Search production Swift for direct `context.insert`, `context.delete`, and `DomainGraphValidator.save` in the Task 2 feature set. Confirm every top-level production action containing those calls is inside `withMutation`. Run `git diff --check`, inspect the complete Task 2 diff, and commit:

```bash
git commit -m "refactor(persistence): scope record mutations"
```

---

### Task 3: Cover transactional Visit, Invoice, and Photograph writers

**Files:**
- Modify: `FarrierFlow/Features/Visits/VisitStartUseCase.swift`
- Modify: `FarrierFlow/Features/Visits/VisitSaveUseCase.swift`
- Modify: `FarrierFlow/Features/Visits/VisitDiscardUseCase.swift`
- Modify: `FarrierFlow/Features/Visits/VisitEditorModel.swift`
- Modify: `FarrierFlow/Features/Visits/Views/VisitEditorView.swift`
- Modify: `FarrierFlow/Features/Invoices/InvoiceGenerationUseCase.swift`
- Modify: `FarrierFlow/Features/Invoices/InvoiceStatusUseCase.swift`
- Modify: `FarrierFlow/Features/Invoices/InvoiceDeletionUseCase.swift`
- Modify: `FarrierFlow/Features/Invoices/InvoiceCreationModel.swift`
- Modify: `FarrierFlow/Features/Invoices/InvoiceDetailModel.swift`
- Modify: `FarrierFlow/Features/Invoices/Views/InvoiceCreationView.swift`
- Modify: `FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift`
- Modify: `FarrierFlow/Features/Photographs/PhotographLibrary.swift`
- Modify: `FarrierFlow/Features/Photographs/PhotographReconciler.swift` only if it can mutate outside `PhotographLibrary`'s retained scope.
- Test: `FarrierFlowTests/Features/Visits/VisitStartUseCaseTests.swift`
- Test: `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`
- Test: `FarrierFlowTests/Features/Invoices/InvoiceCreationModelTests.swift`
- Test: `FarrierFlowTests/Features/Invoices/InvoiceDetailModelTests.swift`
- Test: `FarrierFlowTests/Features/Invoices/InvoiceGenerationUseCaseTests.swift`
- Test: `FarrierFlowTests/Features/Invoices/InvoiceStatusUseCaseTests.swift`
- Test: `FarrierFlowTests/Features/Invoices/InvoiceDeletionUseCaseTests.swift`
- Test: `FarrierFlowTests/Features/Photographs/PhotographLibraryTests.swift`
- Test: `FarrierFlowTests/Features/Photographs/PhotographConcurrencyTests.swift`
- Test: `FarrierFlowTests/Features/Photographs/PhotographReconcilerTests.swift` only if the reconciler receives a direct coordinator scope.

**Interfaces:**
- Consumes: the app-owned coordinator from Task 2.
- Produces: Visit and Invoice use-case entry points with explicit `coordinator:` arguments.
- Produces: `PhotographLibrary.init(container:mutationCoordinator:fileStore:...)`, retaining the shared coordinator.

- [ ] **Step 1: Write RED tests for action-context and asynchronous writers**

Cover real operations that use separate contexts:

- Start Visit invalidates a read generation.
- Save Progress or Complete Visit invalidates a read generation.
- Invoice generation and Mark Paid invalidate a read generation.
- Photograph add retains active-writer state across the existing storage-coordinator suspension point.
- Photograph failure/rollback still invalidates the generation and leaves existing file/data behavior unchanged.

For Photograph concurrency, pause the real operation at its existing deterministic test suspension point, assert `beginRead()` throws `.writerActive`, then release it and verify the original file/metadata result.

- [ ] **Step 2: Run transactional selectors and verify RED**

Run only `VisitStartUseCaseTests`, `VisitEditorModelTests`, `InvoiceGenerationUseCaseTests`, `InvoiceStatusUseCaseTests`, `InvoiceDeletionUseCaseTests`, and `PhotographLibraryTests`. Expected: missing coordinator arguments/initializers or a read generation incorrectly remaining valid.

- [ ] **Step 3: Wrap each complete transaction**

The outermost use case owns the scope:

```swift
static func generate(
    request: InvoiceGenerationRequest,
    in context: ModelContext,
    coordinator: PersistenceMutationCoordinator
) throws -> PersistentIdentifier {
    try coordinator.withMutation {
        // Existing complete Invoice graph insertion, validation, save,
        // rollback, and sequence handling.
    }
}
```

For asynchronous Photograph operations, use the async overload outside the existing Photograph storage permit so the mutation scope covers file preparation, model mutation, save/rollback, and cleanup. Do not create a second coordinator inside action-specific contexts. All contexts associated with the app container share the same app-owned coordinator.

- [ ] **Step 4: Run GREEN for transactional writers**

Run the Task 3 selectors serially. Preserve all existing invoice atomicity, photograph byte/file rollback, Visit graph, and source-integrity assertions.

- [ ] **Step 5: Audit and commit Task 3**

Audit every remaining production SwiftData mutation found by targeted search. Classify preview/UI-test fixture seeding separately and confirm it finishes before export-capable app composition. Run `git diff --check`, inspect the complete Task 3 diff, and commit:

```bash
git commit -m "refactor(persistence): coordinate transactional writers"
```

---

### Task 4: Replace snapshot rescans with generation validation

**Files:**
- Modify: `FarrierFlow/Features/Export/ExportSnapshotBuilder.swift`
- Modify: `FarrierFlow/Features/Export/ExportSnapshotError.swift`
- Modify: `FarrierFlowTests/Features/Export/ExportSnapshotBuilderTests.swift`
- Modify: `FarrierFlowTests/Support/ExportTestFixtures.swift` only if the fixture must supply the coordinator.

**Interfaces:**
- Consumes: `PersistenceMutationCoordinator.beginRead()` and `validate(_:)`.
- Produces: `ExportSnapshotBuilder.build(in:mutationCoordinator:exportContext:batchSize:progress:)`.
- Produces: `ExportSnapshotError.sourceDataChanged` as the generic typed failure for coordinated overlap.
- Removes: the notification/pending-set `SourceGraphMutationGuard` and its unbounded scans.

- [ ] **Step 1: Restore and refine the four material RED regressions**

Use the real coordinator in every concurrent writer task. Cover:

1. A clean scalar update after its model was captured.
2. A forward relationship update after capture.
3. A second update to a model already dirty when export began.
4. A Service inserted before Service capture and deleted after capture/recheck inside one coordinator write scope, leaving public SwiftData pending state at its original baseline.

Also cover `beginRead` rejection when an asynchronous writer is already active. Each test requires `.sourceDataChanged`, no snapshot, and no progress emitted after the mutation is accepted.

- [ ] **Step 2: Run the five selectors and verify RED**

Run only the new/updated snapshot selectors. Expected: `ExportSnapshotBuilder` lacks the coordinator parameter/error or returns a snapshot because the current pending-set guard cannot see the mutation.

- [ ] **Step 3: Add a scoped read-generation guard**

At build entry:

```swift
let readGeneration: PersistenceMutationCoordinator.ReadGeneration
do {
    readGeneration = try mutationCoordinator.beginRead()
} catch {
    throw ExportSnapshotError.sourceDataChanged
}
```

Provide a small main-actor read guard to `SnapshotCooperation`. Every cooperative checkpoint performs cancellation checks, yields, validates the generation, and then resumes work. Validate synchronously before the first progress callback and immediately before returning the immutable snapshot. There must be no await between the final validation and return.

Remove `SourceGraphMutationGuard`, `ModelContext.didSave` observation, pending-model grouping, saved-identifier Sets, and their synchronous equality scans. Convert changed/deleted relationship-hint preprocessing to existing batch-bounded cooperative helpers; do not weaken dangling-relationship validation.

- [ ] **Step 4: Run GREEN and mutation-check the regressions**

Run the five focused selectors, then the complete serial `ExportSnapshotBuilderTests` selector. Temporarily remove the coordinator validation at one cooperative checkpoint and confirm at least one concurrent-mutation test fails; restore it and rerun GREEN.

- [ ] **Step 5: Audit and commit Task 4**

Confirm snapshot construction performs no SwiftData write, serializes no persistence identifier, traverses no owner to-many relationship, and contains no app-owned unbounded scan. Run `git diff --check`, inspect the exact Export diff, and commit:

```bash
git commit -m "fix(export): reject coordinated source changes"
```

---

### Task 5: Cross-feature verification and Unit 2 closure

**Files:**
- Modify: `.agents/workflow/CURRENT_UNIT.md` (ignored; never stage)
- Modify: `.superpowers/sdd/2026-08-08-slice-8-full-owner-export/task-2-report.md` (ignored; never stage)
- Modify: no production file unless a concrete verification failure proves an in-scope defect.

**Interfaces:**
- Consumes: all Task 1-4 commits.
- Produces: reviewed, verified Unit 2 continuation state at `committed-awaiting-push`.

- [ ] **Step 1: Audit every production writer boundary**

Use targeted searches for `context.insert`, `context.delete`, direct model scalar/relationship assignment near a save, `DomainGraphValidator.save`, and `context.save`. For each production result, identify the enclosing top-level action and its coordinator scope. Exclude only read paths and fixture seeding completed before app composition; record the classification in the task report.

- [ ] **Step 2: Run one serial cross-feature checkpoint suite**

Select:

- `PersistenceMutationCoordinatorTests`
- `ExportSnapshotBuilderTests`
- changed Barn, Client, Horse, Appointment, Service, and BusinessProfile model suites
- `VisitStartUseCaseTests` and `VisitEditorModelTests`
- `InvoiceGenerationUseCaseTests`, `InvoiceStatusUseCaseTests`, `InvoiceDeletionUseCaseTests`, and changed Invoice model suites
- `PhotographLibraryTests` and `PhotographConcurrencyTests`

Use the primary iOS 26 simulator, disabled parallel testing, and one worker. Verify the exact executed count and zero failures.

- [ ] **Step 3: Run final static and process checks**

Run `git diff --check`, inspect `git status --short`, verify only authorized files changed, shut down the task simulator, quit Simulator, and confirm no task-owned `xcodebuild`, `xctest`, or `XCTRunner` remains. Manual UI verification is not required because this continuation adds no user-facing surface.

- [ ] **Step 4: Request independent scoped review and fix only material findings**

Review the complete continuation diff against the approved clarification, with special attention to writer bypasses, async scope lifetime, export progress after invalidation, read-only source behavior, and accidental global/singleton ownership. Any material finding returns to its owning TDD task and focused verification.

- [ ] **Step 5: Record closure and stop**

Append exact RED/GREEN commands, test counts, audit results, commits, and remaining concerns to the ignored report. Set `CURRENT_UNIT.md` to `committed-awaiting-push`, record the final SHA, and stop. Do not push or start Unit 3.
