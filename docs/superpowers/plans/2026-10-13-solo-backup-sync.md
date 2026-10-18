# Solo Backup and Sync Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline execution.
> User instructions prohibit commits and control dependency and external-write
> approval. Preserve `.asc/artifacts/` and `.asc/release/`.

**Goal:** Optional free Apple-authenticated cloud protection of solo business
records and photographs, with offline iPhone operation.

**Architecture:** SwiftData saves and a durable outbox feed transactional
workspace-scoped Supabase synchronization. Private photo transfer follows
record synchronization. Server revisions arbitrate changes.

**Tech stack:** Swift 6, SwiftData, SwiftUI, AuthenticationServices, CryptoKit,
Supabase Postgres/Auth/Storage/Realtime; approved official Swift SDK 2.55.3.

**Spec:** `docs/superpowers/specs/2026-10-13-solo-backup-sync-design.md`

## Global constraints

- iPhone only; deployment minimum iOS 18.0; primary runtime iOS 26.
- Preserve production store `FarrierFlowV1` and historical V1/V2 schemas.
- Backup/restore/sync do not depend on Pro; ordinary mutation rules do.
- Use the open Safari tab for Supabase administration.
- No commit, push, release, billing change or unapproved new dependency.

## Review focus

- Legacy USD and newer international-currency graphs preserve their exact values.
- In-flight acknowledgments cannot remove newer local edits.
- Realtime omissions and concurrent commits cannot skip a cursor change.
- Account switching/deletion cannot disclose or re-upload another account's data.
- Concurrent invoice creation cannot duplicate numbers or bill the same work.

### Task 1: Stable identities and migration

Files: current files under `Core/Persistence/Schema/`,
`Migrations/FarrierFlowSchemaV2Models.swift`, `FarrierFlowMigrationPlan.swift`,
`ModelContainerFactory.swift`, `SyncRecordIdentity.swift`,
`FarrierFlowTests/Core/Persistence/SyncIdentityMigrationTests.swift`.

Produces: `SyncRecordIdentifying.syncID: UUID?` and idempotent
`initializeSyncIdentity()`. `SyncRecordIdentity.requireIDs` rejects missing or
duplicate identities. Existing Photograph/Payment `id` remains canonical.

- [ ] Test a connected V2 store with all 15 model kinds and duplicate-looking
      clients, migrate and reopen twice; assert stable unique IDs, financial
      snapshot values, GBP currency and existing photo/payment UUIDs.
- [ ] Observe the identity test failing, implement V3 and custom migration,
      preserve V2 exactly and change current aliases/container registration.
- [ ] Validate identity refusal, fresh construction, V1 migration and reopening.
      Run serialized focused persistence tests on one simulator; expect zero
      failures. Repeat migration tests on iOS 18 because storage migration is
      compatibility-sensitive. Review all schema changes.

### Task 2: Durable local sync transactions

Files: `Features/BackupSync/SyncRecord.swift`, `SyncGraphCodec.swift`,
`SyncJournal.swift`, `SyncJournalStore.swift`, `SyncCoordinator.swift`, persistence
sync-state models and corresponding BackupSync tests.

Consumes Task 1 IDs. Produces validated typed graph envelopes, a durable diff
against the acknowledged baseline in the same business store, exact staged
operations, and `sync() async` with account/workspace generation fencing.
Ledger ruling: derive pending changes from committed data rather than replacing
every editor save. Failed saves and unsaved drafts cannot enter the outbox;
committed cascades remain detectable after relaunch.

- [ ] Test failed save rollback, cascaded tombstones, retry after relaunch,
      duplicate upload receipt, a newer edit while upload awaits, and remote
      graph application rollback. Verify committed changes from normal save
      boundaries, including photo transactions and payment reversal.
- [ ] Test and implement bounded paginated pull, monotonic revision application,
      locally edited records becoming explicit conflicts, reconnect refetch and
      cursor/record save atomicity. Use deterministic transport doubles.

### Task 3: Secure server contract

Files: `supabase/schemas/solo_sync.sql`, `supabase/repairs/`,
`supabase/tests/solo_sync_contract.sql`, `supabase/functions/delete-cloud-account/`,
`docs/handoffs/solo-sync-backend.md`.

Consumes typed envelopes from Task 2. Produces workspace bootstrap, idempotent
batch push, commit-ordered changes pull, private photo authorization and
deletion APIs. Tables and relationships are workspace scoped.
Ledger ruling: user requires Safari administration; retain declarative source
and verified incremental repairs without fabricating CLI migration history.

- [ ] Write allow/deny tests for anonymous, owner, another owner, revoked
      membership and deleted account (including still-valid JWTs). Include
      cross-workspace references, forged IDs, rollback and bounded batch inputs.
- [ ] Implement tested SQL/RPCs, revision conflict responses, member-scoped
      Realtime invalidations, photo access and deletion worker fencing.
- [ ] Test designated invoicing-device generations, takeover conflicts and
      one-time billing constraints.
      Apply reviewed SQL through Safari only after required access confirmation;
      run direct query tests, inspect advisors and read back the schema.

### Task 4: Native Apple account and transport

Files: approved pinned SDK reference/lockfile, `Configuration/Supabase.xcconfig`,
`AppleSignInService.swift`, `SupabaseSyncTransport.swift`, session keychain store,
app entitlements/composition, and focused Auth/transport tests.

- [ ] Securely generate and verify a nonce, exchange native Apple credentials,
      persist/refresh sessions and cancel all account-owned work on sign-out.
      Test stale completion, refresh failure and mismatched account binding.
- [ ] Configure native Apple audiences and revocation/deletion server secrets
      without placing private keys in iOS. Verify actual hosted Apple sign-in
      and revocation on a physical iPhone before release acceptance.

### Task 5: Photos, merge review and native account surface

Files: `SyncPhotographTransfer.swift`, existing PhotographLibrary/FileStore
coordination, `Views/BackupSyncView.swift`, `SyncConflictModel.swift`, Clients
routes/menu, RootView composition and `Localizable.xcstrings`.

- [ ] Test interrupted transfers, missing object, corrupt JPEG/hash, photo
      deletion during upload/download and protected-file reconciliation.
- [ ] Implement progressive photo restoration and truthful protection counts.
- [ ] Implement optional benefit/privacy presentation, status/retry, UUID-based
      reconciliation and explicit lookalike/conflict review without destructive
      guessing. Test account-free continuation and free restore independently
      of purchase status. Preserve issued snapshots on number collisions.
- [ ] Implement confirmed server deletion with local retention and account
      switching safeguards. Verify light/dark, Dynamic Type and VoiceOver.

### Task 6: Acceptance and documentation

- [ ] Run focused then required iOS 18/iOS 26 unit/integration/build/UI gates,
      string-catalog validation, real on-disk migration and two-iPhone hosted
      offline/reconnect/photo/sign-out/deletion acceptance.
- [ ] Update product/data/architecture/roadmap with implemented behavior and
      exact remaining gates; prepare privacy changes without publishing them.
- [ ] Review full diff and task-owned processes; clean up processes. Report
      precisely which evidence is local, synthetic hosted or physical-device.
