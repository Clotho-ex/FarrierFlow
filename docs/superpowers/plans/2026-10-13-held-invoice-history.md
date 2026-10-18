# Held Invoice History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task using the previously selected native,
> inline execution method. Steps use checkbox syntax for tracking. User approval
> of this written plan is required before code changes. No commits are authorized.

**Goal:** Preserve reviewed, original invoices locally while syncing safe records
and preventing cloud acceptance of rebilling against their exact source work.

**Architecture:** A versioned immutable archive lives in the business store's
sync journal. V4 WorkItems carry permanent billing holds; a version-2 sync
contract enforces them without rewriting pending legacy operations. Reviewed
recovery commits archive, holds, active graph and journal together; independent
local archive access provides read-only details/PDFs after cloud deletion.

**Tech Stack:** Swift 6, SwiftData, SwiftUI, existing PDF renderer and Supabase
Postgres/RPCs; existing approved supabase-swift 2.55.3. No new dependency.

**Spec:** `docs/superpowers/specs/2026-10-13-held-invoice-history-design.md`

## Global Constraints

- iPhone only; iOS 18 minimum, iOS 26 primary runtime.
- Preserve V1/V2/V3 persisted definitions, identities and `FarrierFlowV1` store.
- Preserve original invoice numbers, UUIDs, currency, exact Int64 amounts,
  payments and issued snapshots. No silent renumbering or currency conversion.
- Holds fence `(workspaceID, WorkItem UUID)`, not names or physical-work lookalikes.
- History remains local-only, outside cloud batches, and never counts as protected.
- Recovery and read-only export are available without granting Pro mutation rights.
- Use only Safari for Supabase administration. Prepare server changes locally;
  request separate approval before installing the new Dev protocol/hold repair.
- No secret entry, cron changes, production changes, billing, commit, push or release.
- Preserve existing user changes and `.asc/artifacts/` / `.asc/release/`.
- Physical Apple/two-iPhone acceptance remains explicitly deferred, not waived.

## Review Focus

- A V2 upgrade traverses V3 after aliases move to V4: historical initialization
  must fetch V3 entities, not the new current aliases (Task 1).
- An upgrade-required workspace must still settle an exact lost-ack operation
  before any new batch or pull is allowed (Tasks 3 and 4).
- A hold survives removal of an already-existing cloud invoice; a stale phone
  cannot clear the hold to bill that WorkItem again (Tasks 1 and 3).
- Save failure or a concurrent local/cloud change cannot leave archive, holds,
  outbox or recovery cursor partly advanced (Task 4).
- Cloud deletion and duplicate PDF filenames must not hide or overwrite local
  invoice history (Tasks 2 and 5).

## File Map and Responsibilities

- Frozen V3 definitions: new
  `FarrierFlow/Core/Persistence/Migrations/FarrierFlowSchemaV3Models.swift`.
  Preserve the existing V3 schema identity and all sixteen persisted models.
- Current V4: new `Core/Persistence/Schema/FarrierFlowSchemaV4.swift`; existing
  sixteen model files become V4 definitions, with WorkItem's optional hold added.
- Existing migration plan, aliases, container, identity initializer and journal
  store select the correct historical/current schema explicitly.
- New `Features/BackupSync/InvoiceHistoryArchive.swift` defines immutable data;
  `InvoiceHistoryArchiveReader.swift` validates/builds isolated local history.
- New `Features/BackupSync/SyncInvoiceRecovery.swift` plans validated recovery;
  `SyncInvoiceRecoveryModel.swift` owns reviewed state and explicit confirmation.
- Existing codec/journal/store/coordinator implement atomic application and retries;
  transport and SQL implement protocol-2 and server billing invariants.
- New `Features/Invoices/InvoiceHistoryModel.swift` and
  `Views/InvoiceHistoryView.swift` render read-only history and export it.
- Existing invoice list, backup/conflict routes, protection counts/copy, string
  catalog and DEBUG test fixtures expose recovery and truthful local-only status.

Paths in tasks below are relative to the active checkout. Existing feature paths
are under `FarrierFlow/`; tests are under `FarrierFlowTests/` or `FarrierFlowUITests/`.

## Validation Commands

Reuse `/tmp/farrierflow-sync-validation.QRXqs5/DerivedData` when still valid.
Use serial non-watch commands, one destination, no overlapping build/test process:

```sh
xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
  -destination 'platform=iOS Simulator,id=A9501C1D-4747-4310-8F2B-F0587E0E30C6' \
  -derivedDataPath /tmp/farrierflow-sync-validation.QRXqs5/DerivedData \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -collect-test-diagnostics never \
  -only-testing:FarrierFlowTests/SUITE \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- ONLY_ACTIVE_ARCH=YES
```

`SUITE` is replaced by each exact suite listed below; combine selectors for
related suites. Verify current simulator availability before execution. Repeat
migration/final compatibility gates using iOS 18 destination
`02DB4E38-DF46-4F30-A8C8-C4D4DF46FDA4`. Expected success: actual nonzero test count,
zero failures and `TEST SUCCEEDED`. New suites first demonstrate a meaningful RED.

### Task 1: V4 Persistence and Local Billing Fence

**Files:** Create frozen V3 models and V4 schema listed above. Modify
`Core/Persistence/Schema/{Client,Barn,Horse,Appointment,AppointmentHorse,Visit,
VisitHorse,Photograph,Service,WorkItem,BusinessProfile,Invoice,InvoiceVisit,
InvoiceLineItem,Payment,SyncState}.swift`, `Schema/CurrentSchema.swift`,
`Migrations/FarrierFlowMigrationPlan.swift`, `ModelContainerFactory.swift`,
`SyncRecordIdentity.swift`, `DomainGraphValidator.swift`,
`Features/BackupSync/SyncJournalStore.swift`, `SyncGraphCodec.swift`,
`Features/Invoices/InvoiceEligibilityRules.swift`, `InvoiceGenerationUseCase.swift`.
Create tests `Core/Persistence/InvoiceHistoryMigrationTests.swift` and
`Features/Invoices/InvoiceBillingHoldTests.swift`; extend schema/reopen/codec tests.

**Interfaces:** Produces `WorkItem.billingHoldID: UUID?` and
`WorkItem.applyBillingHold(_ invoiceID: UUID) throws` (nil→UUID or same UUID only).
Add `SyncRecordIdentity.initializeV3(in: ModelContext) throws` for the historical
V2→V3 stage; keep current initialization explicitly typed for current models.

- [x] Write RED tests: `v3ReopenPreservesPaidGBPGraphAndExactJournalBytes`,
  `v1AndV2UpgradeThroughHistoricalV3`, `holdCannotChangeOrClear`, and
  `heldWorkIsNotSelectableOrBillableAndDoesNotConsumeNumber`. Assert paid/unpaid
  snapshots, all IDs, original outbox/receipts/deletion flags, nil legacy holds,
  duplicate-looking clients and repeated reopen. Include a held work item whose
  active invoice is subsequently removed by an already-permitted domain action.
- [x] Run `InvoiceHistoryMigrationTests`, `InvoiceBillingHoldTests` and existing
  `SyncIdentityMigrationTests`; confirm the missing hold/V4 behavior fails.
- [x] Freeze V3 without altering its persisted shape; move current definitions
  to V4 and add lightweight V3→V4 migration. Retarget aliases/container/current
  SyncState access. Explicitly initialize V3 entities in V2→V3, not V4 aliases.
- [x] Implement monotonic hold validation and exclusion at both invoice selection
  and creation boundaries. Capture the hold in new WorkItem records; accept absent
  legacy holds as nil only, rejecting invalid UUIDs and unknown extra keys.
  Graph validation permits an existing active line item alongside a hold.
- [x] Run these suites plus `SchemaContractTests`, `PersistentStoreReopenTests`,
  `SyncGraphCodecTests`, `InvoiceGenerationUseCaseTests` and
  `InvoiceCreationModelTests`; repeat the migration suites on iOS 18. Review the
  frozen shape and ensure no invoice/payment behavior was otherwise weakened.

### Task 2: Immutable Local Archive and Independent Reader

**Files:** Create `Features/BackupSync/InvoiceHistoryArchive.swift`,
`InvoiceHistoryArchiveReader.swift`; modify `SyncJournal.swift` and
`SyncJournalStore.swift`. Create `Features/BackupSync/InvoiceHistoryArchiveTests.swift`
and `InvoiceHistoryArchiveReaderTests.swift`.

**Interfaces:** `InvoiceHistoryArchive: Codable, Equatable, Sendable` contains
version 1, archive UUID, account/workspace UUIDs, captured date, reason, optional
source operation UUID, complete `[SyncRecord]`, selected invoice UUIDs and exact
`[UUID: [UUID]]` invoice→work mapping. Journal's optional archive array defaults
to empty for old JSON. `InvoiceHistoryArchiveReader(container: ModelContainer)`
produces `archives() throws -> [InvoiceHistoryArchive]` and
`content(archiveID: UUID, invoiceID: UUID) throws -> InvoicePDFContent`.

- [x] Write RED tests `archiveRoundTripsPaidAndUnpaidExactHistory`,
  `readerWorksSignedOutAndAfterCloudDeletion`, `archiveCannotBeReplaced`, and
  `unknownOrCorruptArchiveFailsWithoutChangingStoredBytes`. Assert original GBP
  amounts/number/payment snapshots, exact source mapping and no cloud SDK access.
- [x] Run the two archive suites; confirm missing archive APIs fail.
- [x] Implement immutable versioned archive validation: selected invoices must
  exist in a complete valid captured graph; mappings must match their line items;
  reject duplicate archive/invoice identities within an envelope and wrong local
  binding. Multiple envelopes retain their independent source graphs.
- [x] Read raw local journal archive data without the `cloudDeleted` sync guard,
  while keeping all decode/binding validation. Populate an isolated in-memory
  context through the codec and resolve the archived invoice by its UUID. Build
  content with `InvoicePDFContentBuilder`; do not leak its temporary persistent ID
  into active navigation or expose mutation actions.
- [x] Run archive suites and `SyncJournalTests`, `SyncJournalStoreTests`,
  `CloudDeletionControllerTests`, `InvoicePDFContentBuilderTests`; verify archive
  bytes never enter batches and ordinary journal/deletion fencing remains intact.

### Task 3: Server-Enforced Holds and Protocol-2 Contract

**Files:** Modify `supabase/schemas/solo_sync.sql`; create reviewed repair
`supabase/repairs/2026-10-13-invoice-history-protocol.sql` and rollback fixture
`supabase/tests/invoice_history_contract.sql`. Create
`Features/BackupSync/SyncPushRejection.swift`. Modify
`Features/BackupSync/SupabaseSyncTransport.swift`, `SyncJournal.swift` and
`SyncCoordinator.swift`; extend `SupabaseSyncTransportTests.swift`,
`SyncJournalTests.swift` and `SyncCoordinatorTests.swift`.

**Interfaces:** Add `SyncProtocolVersion` values 1/2; journal stores optional
`pendingProtocolVersion` (missing with a pending operation means legacy 1).
New batches stage as version 2; staged legacy batches retain original content.
Extend `SyncTransport.push(_:protocolVersion:)` and
`pull(workspaceID:cursor:protocolVersion:)`; bootstrap returns the workspace
minimum protocol via `SyncWorkspaceInfo.minimumProtocolVersion` (legacy defaults
to 1). New RPCs: `ff_sync_bootstrap_v2`, `ff_sync_push_v2(p_batch jsonb)` and
`ff_sync_pull_v2(p_workspace uuid, p_cursor bigint, p_limit integer)`.

Produces `SyncPushRejectionReason` cases `.invoicingAuthority`,
`.invoiceNumberCollision`, `.alreadyBilled`, `.protocolUpgradeRequired`, and
`SyncConfirmedRejection` containing the exact `SyncBatch`, protocol version and
reason. Only recognized server rollback outcomes construct a confirmed rejection;
unrecognized errors remain ambiguous and do not retire a pending operation.

- [x] Write client RED tests for legacy absent-field decoding, protocol-2 routes,
  pending legacy request equality after reopen, unknown protocol refusal and
  `upgradeGateDoesNotPreventCachedLegacyReceiptSettlement`.
- [x] Write rollback SQL assertions for owner-only hold writes, immutable hold
  values, absent/null/replace attempts, same-batch new billing, retained existing
  line item, held-work tombstone resurrection, stale generation and cross-owner
  access. Include the first-hold minimum-version transition, legacy commit/pull
  refusal, identical cached legacy receipt and changed-payload receipt denial.
- [x] Implement new-contract validation and workspace minimum protocol 2 at the
  first non-null hold commit, under the existing workspace lock. A hold is an
  opaque canonical UUID, not an invoice relationship. Reject new line items
  against held work even if the hold is added in this transaction; only already
  committed, immutable line-item identities may remain. Keep authorization and
  all financial/number/history checks.
- [x] Before holds exist, legacy-shaped records remain supported by the legacy
  contract; its pulls omit only null hold fields, never a non-null fence. After
  the minimum rises, no legacy new commit/pull is allowed. Consult a matching
  cached receipt before the protocol gate without changing its request hash;
  never normalize or relabel a client's pending operation.
- [x] Implement exact protocol routing, strict typed update-required/rejection
  outcomes and bounded full-transaction decoding. Bootstrap negotiation permits
  settling a pending operation before enforcing the gate on new sync. Preserve
  old request DTOs/receipt semantics and update existing transport doubles.
- [x] Run client suites. After separate user approval, install the reviewed Dev
  repair through Safari, run rollback SQL and concurrent-session hold/billing
  tests, and separately read back grants/minimum-version behavior and zero fixture
  residue. Do not claim local transport tests establish hosted enforcement.

### Task 4: Explicit, Atomic Invoice Recovery

**Files:** Create `Features/BackupSync/SyncInvoiceRecovery.swift` and
`SyncInvoiceRecoveryModel.swift`; modify `SyncGraphCodec.swift`, `SyncJournal.swift`,
`SyncJournalStore.swift`, `SyncCoordinator.swift`, `BackupSyncRuntime.swift`.
Create `SyncInvoiceRecoveryTests.swift` and `SyncInvoiceRecoveryModelTests.swift`.

**Interfaces:** Consumes Task 3's exact `SyncConfirmedRejection`.
`SyncInvoiceRecoveryReview` retains account,
workspace, complete reviewed local graph/journal, projected cloud graph/revision,
affected invoice UUIDs and candidate canonical settings. Model APIs:
`load(accountID: UUID) async throws` and
`confirm(accountID: UUID, settings: SyncRecoverySettingsChoice) async throws`.
Execution correction: recheck cloud revision and invoicing authority before the
atomic local save. This asynchronous check is not a distributed transaction;
billing safeguards remain pending until the server acknowledges their holds.
Settings choices are `.keepLocal` / `.useCloud`, always preserving cloud profile
UUID and designated-device sequence authority. Store API:
`applyRecovery(_ review: SyncInvoiceRecoveryReview,
settings: SyncRecoverySettingsChoice) throws`.
Codec-only application API:
`SyncGraphCodec.applyRecovery(_ records: [SyncRecord], archive: InvoiceHistoryArchive,
in context: ModelContext, journal: SyncJournal) throws`, which verifies exact
archive proof before selectively relaxing the removed-invoice collision guard.

- [x] Write RED tests for paid/unpaid printed-number collisions, stale-generation
  offline invoices, same-source cloud billing, independently initialized profile,
  same-currency canonical settings, mixed-currency refusal and unchanged lookalikes.
  Assertions: archive exact snapshots, original numbers, stable hold IDs, safe
  active dependencies, cloud profile identity/authority and no duplicate billing.
- [x] Add RED tests for lost acknowledgment, unknown transport error, unsaved
  draft, account change, stale local graph/journal, changed cloud revision,
  injected save failure and reopen after successful recovery. Compare whole
  graph/outbox/archive/hold state before/after failures, not just counts.
- [x] Classify only explicit server-proven rejections as recoverable. Preserve
  ambiguous pending operations; settle cached receipts first. Obtain a complete
  projected cloud graph without partially applying it or discarding the pending
  operation. Do not auto-archive already-acknowledged cloud invoices.
- [x] Plan the safe graph deterministically: remove only selected local invoice
  subgraphs (invoice/visits/lines/payments), retain their complete archive, apply
  source-work holds, preserve immutable cloud invoices, reconcile explicitly chosen
  profile settings and retain designated numbering. Refuse unsafe dependency,
  identity, currency or authority combinations rather than making partial merges.
- [x] Add a narrow codec recovery application path that verifies archive proof
  against the exact original graph and selected invoice identities. Ordinary
  `apply` retains all strict history/collision guards. Recheck reviewed state and
  drafts; write archive, holds, recovered graph and journal/cursor through the same
  main-context save. Roll back everything on failure. No general bypass boolean.
- [x] Run both recovery suites plus codec/journal/coordinator/conflict suites.
  Verify normal same-UUID review, tombstones, exact retries, account epochs and
  existing deletion fences retain their behavior.

### Task 5: Native Recovery, Read-Only History and Truthful Status

**Files:** Create `Features/Invoices/InvoiceHistoryModel.swift`,
`Views/InvoiceHistoryView.swift`, `Features/BackupSync/Views/SyncInvoiceRecoveryView.swift`;
modify `Features/Invoices/Views/InvoiceListView.swift`, `InvoiceRoutes.swift`,
`Features/Clients/Views/ClientListView.swift` destination registration,
`Features/BackupSync/Views/BackupSyncView.swift` (including its `BackupSyncCopy`),
`Views/SyncConflictReviewView.swift`, `BackupSyncModel.swift`,
`SyncProtectionStatus.swift`, `Resources/Localizable.xcstrings`,
`App/BackupSyncUITestFixtures.swift`. Reuse `InvoicePDFShareModel.swift`,
`InvoicePDFDocumentWriter` and `Features/Invoices/PDF/InvoicePDFTemporaryFileStore.swift`.
Create `InvoiceHistoryModelTests.swift`; extend protection tests and
`FarrierFlowUITests/BackupSyncUITests.swift`.

**Interfaces:** `InvoiceHistoryModel(container: ModelContainer)` provides
`load() throws`, immutable summaries keyed by `(archiveID, invoiceID)`, and
`preparePDF(archiveID: UUID, invoiceID: UUID) async`. Extend protection status with
`localOnlyInvoiceCount` and `pendingBillingHoldCount`; `isFullyProtected` is false
when any held local-only invoice exists, even if every active record is acknowledged.

- [x] Write RED tests for readonly history without Pro/session, duplicate printed
  numbers, independent temporary PDF folders, failed export/cancellation cleanup,
  original PDF content and protection counts before/after hold acknowledgment.
- [x] Implement native Form recovery review/confirmation, a separate Invoice
  History section with read-only details and Share PDF, and truthful labels:
  "Local-only invoice history", "Not cloud-protected", "Billing safeguard awaiting
  sync" and "Update Required". No archive delete/edit/payment/billing affordance.
- [x] Reuse existing money/date/locale formatting and PDF writer; isolate export
  folders by archive/invoice identity. Use the local reader even when sync status
  is unavailable after deletion. Do not construct the SDK merely to view history.
- [x] Run model/PDF/protection tests and focused recovery/history UI tests. Verify
  Light/Dark/XXXL, VoiceOver where tooling provides real hierarchy evidence, and
  ordinary account-free/Pro gates. DEBUG fixtures use synthetic local data only;
  no Apple prompts or real business data in UI tests.

### Task 6: Integrated Verification and Handoff

**Files:** Update `docs/handoffs/solo-sync-backend.md`, current-unit workflow and
solo-sync progress ledger; update product/data/architecture documentation only to
describe behavior actually implemented and evidence actually established.

- [x] Run relevant migration, archive, recovery, protocol, invoice/PDF, photo,
  account and deletion matrices serially on iOS 26 and iOS 18. Run broader tests
  where the schema migration/observed failures require them; never substitute
  compilation for behavioral assertions. Verify Release and minimum-iOS builds.
- [x] Finish approved hosted rollback and concurrent tests, current solo-sync and
  deletion contracts; verify the new protocol did not regress owner-only photo or
  deletion access. Separate hosted evidence from synthetic local results.
- [x] Validate the catalog and final tracked/untracked source diff. Perform the
  workflow-required fresh final review and independently verify its findings.
  Stop task-owned runners/apps and remove task temporary export files; leave no
  watchers, duplicate builds or accidental credentials.
- [x] Report exact tests/builds and remaining external approval/configuration or
  physical-device gates. No commit, push, release or declaration of whole-feature
  readiness while required hosted/real-device acceptance is still outstanding.

## Self-Review and Execution Gate

All approved spec sections map to Tasks 1–5; required acceptance maps to Task 6.
The five Review Focus cases are explicit tests in their owning tasks. Historical
schema initialization, legacy pending routing and independent archive reading
were checked against current source while preparing this plan. Server installation
is separately authorized, not implied by approval of a local implementation plan.

Execution was approved and completed native/inline, with the separately approved
Dev repair installed through Safari. Shared serial verification and review
evidence is retained in `.superpowers/sdd/2026-10-13-held-invoice-history/`.
No commits are authorized or performed. Overall solo-sync release gates remain
explicit in `docs/handoffs/solo-sync-backend.md`.
