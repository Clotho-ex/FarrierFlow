# Slice 3 — Hoof Photographs Design

**Status:** Approved for specification review

**Date:** 2026-07-28

**Implementation:** Not started

## Purpose

Slice 3 adds durable, local-first hoof photographs to the existing Visit
workflow. A farrier can capture or import photographs for any scheduled horse,
retain them with that horse's Visit history, reopen them after process
termination, and delete them explicitly.

The slice stores one normalized JPEG per Photograph in Application Support and
stores Photograph metadata and ownership in SwiftData. It does not add
networking, accounts, CloudKit, synchronization, remote storage, app-managed
backup, export, or replacement history.

## Approved Approach

Use a file-backed `Photograph` model owned by `VisitHorse`, staged filesystem
transactions, and fail-safe filesystem reconciliation.

Two alternatives were rejected:

1. Direct file writes followed by database saves have fewer components but
   leave unsafe crash windows, partial files, and stranded metadata without a
   reliable recovery boundary.
2. Retaining originals, derivatives, and a persisted operation journal provides
   a larger audit trail but violates the approved minimal scope and multiplies
   storage, migration, privacy, and recovery complexity.

## Product Outcome

A Photograph belongs to exactly one `VisitHorse`. It may be added while the
VisitHorse outcome is Pending, Serviced, or Not Serviced.

This ownership supports photographs of:

- Hoof condition before work.
- Safety or health concerns.
- Work performed.
- Reasons a horse was not serviced.
- Before-and-after state.

Changing a VisitHorse outcome does not delete, reassign, or otherwise mutate its
Photographs. Completed Visit correction may change the outcome or Work Notes
without changing Photograph ownership or metadata.

Visit-level ownership is not supported because a Visit may contain multiple
horses and would require separate horse-identification metadata.

## Supported Operations

The Photograph feature supports:

- Creation from camera capture.
- Creation from system photo-library selection.
- Display from Visit and Horse History contexts.
- Explicit deletion.
- Deletion of broken metadata whose canonical file is missing.
- Photo-aware cleanup when an in-progress Visit is discarded.
- Idempotent reconciliation after an interrupted file or database operation.

The Photograph feature does not support:

- Ownership reassignment.
- Metadata editing.
- UUID mutation.
- Creation-date mutation.
- Dimension mutation.
- Byte-count mutation.
- In-place file replacement.
- Version history.

To replace a Photograph, the user deletes it and adds a new Photograph. The new
record receives a new UUID and creation date.

## SwiftData Schema V3

Preserve `FarrierFlowSchemaV1` and `FarrierFlowSchemaV2` as immutable prior
schema snapshots.

Add a complete `FarrierFlowSchemaV3` containing the existing seven model types
plus `Photograph`.

### Photograph

| Field | Type | Contract |
| --- | --- | --- |
| `id` | `UUID` | Required, unique, generated before normalization |
| `createdAt` | `Date` | Required app-ingestion time |
| `pixelWidth` | `Int` | Required positive normalized width |
| `pixelHeight` | `Int` | Required positive normalized height |
| `byteCount` | `Int64` | Required positive normalized JPEG byte count |

### Relationships

- `Photograph.visitHorse` is the inverse of
  `VisitHorse.photographs`.
- Every Photograph belongs to exactly one VisitHorse in the domain.
- SwiftData storage may represent `Photograph.visitHorse` as optional only when
  required for the established iOS 18 deletion-safe inverse strategy.
- Controlled creation always supplies a valid VisitHorse.
- `VisitHorse.photographs` begins empty and owns the persistence lifetime of its
  Photograph metadata.
- Deleting a Photograph never deletes its VisitHorse.
- Deleting an allowed in-progress Visit cascades through VisitHorse to its
  Photograph metadata only after the photo-aware discard transaction has
  quarantined the files.

No persisted ordering field is added. Presentation order is deterministic:

1. `createdAt` ascending.
2. UUID canonical string ascending.

### Persisted Metadata Exclusions

Do not persist:

- Absolute or relative file paths.
- Original filename.
- Original photo-library asset identifier.
- Camera or library source kind.
- EXIF or GPS metadata.
- Source timestamp or device metadata.
- Caption.
- Hoof classification.
- Before-or-after classification.
- Thumbnail metadata.
- Replacement or version history.
- Original-owner metadata.
- Cleanup or transaction state.

## Domain Validation

Stateless domain-graph validation verifies current graph validity only:

- Photograph UUID is unique.
- Photograph has a valid VisitHorse relationship.
- VisitHorse contains the inverse Photograph relationship.
- Pixel dimensions are positive.
- Longest pixel dimension does not exceed 2560.
- Byte count is positive.

Stateless validation does not claim to prove that ownership or scalar values
never changed historically.

Immutability is enforced by the supported production operations:

- Photograph creation initializes all persisted values once.
- Photograph deletion removes the record.
- No production operation assigns `id`, `createdAt`, `pixelWidth`,
  `pixelHeight`, `byteCount`, or `visitHorse` after insertion.
- No editing or reassignment interface exists.
- All Photograph mutations remain behind the feature-owned creation and
  deletion boundaries.

SwiftData may require mutable stored properties, but framework storage
requirements do not authorize production reassignment.

File availability is not a universal graph-validity requirement. Metadata whose
canonical file is missing remains a valid unavailable record and must not block
unrelated Visit corrections or other graph saves.

## Schema Migration

The migration chain becomes:

```text
FarrierFlowSchemaV1
    → FarrierFlowSchemaV2
    → FarrierFlowSchemaV3
```

Add an explicit lightweight V2-to-V3 migration stage while preserving the
existing V1-to-V2 stage.

Migration requirements:

- Preserve the existing production store identity and URL.
- Preserve every V1 and V2 record and relationship.
- Existing VisitHorse records receive empty Photograph collections.
- Fabricate no Photograph record.
- Fabricate no photograph file.
- Fabricate no Photograph-to-VisitHorse relationship.
- Fabricate no unavailable placeholder.
- Verify direct V2-to-V3 migration.
- Verify chained V1-to-V2-to-V3 migration.

The additive migration must be proven safe on iOS 18 before release. If the
lightweight migration is unsafe there, implementation stops for schema review.
The production store must never be recreated or replaced.

## Canonical File Storage

The application-owned storage tree is:

```text
Application Support/
└── HoofPhotographs/
    ├── <lowercase-photograph-uuid>.jpg
    ├── Temporary/
    │   └── <photograph-uuid>.<operation-uuid>.tmp
    └── Quarantine/
        └── <photograph-uuid>.<operation-uuid>.jpg
```

The root directory name, subdirectory names, naming grammar, and extensions are
application constants.

The application derives a canonical file URL exclusively from the Photograph
UUID. It never accepts or persists a user-provided path.

The Photograph UUID is generated before normalization. The same UUID identifies
the temporary file, canonical file, quarantine candidates, and SwiftData
record. A separate operation UUID makes temporary and quarantine filenames
unique while preserving their recoverable Photograph identity.

Temporary and quarantine directories live inside Application Support and on the
same filesystem volume as the canonical directory so atomic moves can be used.

Every create and move operation uses no-overwrite behavior. A collision with a
temporary, quarantine, canonical, or SwiftData UUID for a newly generated
Photograph fails visibly. Existing content is never overwritten and collision
handling does not silently generate a replacement identity within the same
operation.

## Managed-File Boundary

Filesystem mutation is allowed only for regular files that:

- Are contained inside an application-owned HoofPhotographs directory.
- Match the exact lowercase UUID naming grammar.
- Use the expected canonical, temporary, or quarantine convention.
- Pass containment and regular-file inspection without following symbolic
  links.

The application does not follow symbolic links.

Unknown files, malformed names, directories, symbolic links, or unexpected
entries remain untouched and are logged locally. They are never deleted merely
because they appear under the HoofPhotographs root.

## File Protection and Device Backup

Apply complete file protection to:

- The HoofPhotographs root.
- Temporary and Quarantine directories.
- Temporary files.
- Quarantine files.
- Canonical JPEG files.

A protected-data access failure while the device is locked is not equivalent to
a missing file.

Do not set a backup-exclusion resource value on the HoofPhotographs tree.
Photographs are user-created business records that may be impossible to
recreate, so standard Apple operating-system device backup is permitted.

FarrierFlow still does not implement:

- CloudKit.
- Synchronization.
- Accounts.
- App-managed backup.
- Remote storage.
- Backup settings.
- Conflict resolution.

## Capture and Photo-Library Import

Support:

- Native camera capture when a camera is available.
- System `PhotosPicker` import.

The system photo picker does not require broad photo-library permission. The app
does not retain a library asset identifier and cannot re-fetch the selected
asset later.

Camera capture and photo-library import enter the same normalization and
persistence pipeline.

Slice 3 ingests one Photograph per action. It does not define an all-or-nothing
batch-import transaction.

Camera permission denial and unavailable-camera conditions use native,
recoverable unavailable states. The camera usage description remains
English-only and localization-ready.

The original camera or picker payload is transient. It is never stored in the
managed permanent tree and is released after either success or failure.

## Normalization Envelope

The sole application-owned image uses:

- Maximum longest edge: 2560 pixels.
- JPEG quality: 0.82.
- Output color representation: sRGB.
- Preserved aspect ratio.
- No upscaling.
- Upright stored pixels.
- No source metadata.

The app does not retain:

- Original HEIC, JPEG, RAW, PNG, or library asset.
- Original-plus-processed pairs.
- A persistent thumbnail file.
- EXIF orientation dependency.

## Bounded Decode Pipeline

Normalization must not routinely decode an unbounded full-resolution source
into a full-size pixel buffer before resizing.

The pipeline uses ImageIO downsampling or an equivalent bounded decoder:

1. Inspect source properties needed for validation, dimensions, color handling,
   and orientation without performing an eager full-resolution render.
2. Reject invalid, zero-dimension, unsupported, or undecodable sources.
3. Calculate the target longest edge as
   `min(sourceLongestEdge, 2560)`.
4. Downsample toward that target during decode.
5. Apply source orientation while producing upright pixels.
6. Render into an opaque sRGB destination while preserving the visual
   appearance of supported Display P3 or other supported source color spaces.
7. Preserve aspect ratio.
8. Never upscale.
9. Encode one JPEG at quality 0.82.
10. Write to a uniquely named temporary file without overwriting.
11. Reopen and validate the produced JPEG, normalized dimensions, byte count,
    and orientation independence.
12. Verify that no EXIF, GPS, device, timestamp, orientation, filename, asset,
    or other source metadata was copied.

The actual file write remains authoritative. A reasonable
volume-capacity estimate is performed before final persistence where the
platform provides one, but the estimate is never treated as a guarantee.

No persistent thumbnail is produced. Lists and grids use asynchronous ImageIO
downsampling from the canonical JPEG with optional memory-only caching.

## Feature-Owned Storage Coordination

Introduce one feature-owned `PhotographStorageCoordinator` responsible for
exclusive execution of:

- Photograph add.
- Photograph delete.
- Photo-aware in-progress Visit discard.
- Reconciliation planning.
- Reconciliation execution.

Reconciliation must never run concurrently with an add, delete, or Visit
discard. A mutation must not start while reconciliation is planning or
executing.

The coordinator uses the smallest local serialization mechanism suitable for
the feature, such as a feature-owned actor or equivalent serial coordinator
with a FIFO async gate.

Swift actor reentrancy alone is not considered sufficient. The exclusive permit
must remain held across every suspension point in a complete logical operation,
including normalization, atomic moves, SwiftData saves, rollback, restoration,
cleanup, reconciliation planning, and reconciliation execution.

Permit release is guaranteed after:

- Success.
- Thrown validation failure.
- Normalization failure.
- File operation failure.
- SwiftData failure.
- Rollback or restoration failure.
- Cancellation.
- Reconciliation preflight failure.
- Reconciliation execution failure.

No global application lock, persisted journal, generalized task scheduler, or
third-party synchronization dependency is added.

Destructive Photograph file APIs remain hidden behind the coordinator so
production call sites cannot bypass serialization.

Image display reads do not require the exclusive permit. Readers must tolerate a
file being legitimately removed after a completed delete and render the normal
unavailable state rather than crashing.

## Per-VisitHorse Limit

Each VisitHorse may have at most 16 available Photographs.

The limit counts only successfully persisted Photograph metadata whose valid,
accessible canonical managed file belongs to that VisitHorse.

The limit does not count:

- A selected or captured source.
- An operation still processing.
- A failed operation.
- A temporary file.
- A rolled-back operation.
- Metadata whose canonical file is genuinely missing.
- A protected file that is temporarily inaccessible while protected data is
  unavailable.

While holding the exclusive storage permit, Add re-fetches and validates the
VisitHorse and re-evaluates the available count immediately before accepting a
new Photograph. This prevents two additions from both accepting the final
slot.

When the count reaches 16:

- Disable or reject camera and library ingestion.
- Explain that the horse already has 16 photographs.
- Allow explicit deletion.
- Never silently remove an older Photograph.

## Photograph Add Transaction

Use a dedicated Photograph mutation `ModelContext` so rollback cannot discard
unrelated Visit editor work.

The complete operation runs under one exclusive storage-coordinator permit:

1. Generate the Photograph UUID, operation UUID, and immutable app-ingestion
   date.
2. Resolve and validate the VisitHorse in the dedicated context.
3. Re-evaluate the 16-available-Photograph limit.
4. Perform a reasonable storage-capacity estimate.
5. Normalize and encode into a uniquely named temporary file.
6. Reopen and validate the JPEG, dimensions, metadata absence, and byte count.
7. Atomically move the temporary file to the UUID-derived canonical path
   without replacing an existing file.
8. Insert Photograph metadata and required VisitHorse ownership.
9. Validate the current Photograph graph.
10. Save the dedicated SwiftData context.
11. Release the transient source payload.

If normalization or writing fails:

- Insert no permanent metadata.
- Remove any managed temporary file when possible.
- Preserve all existing Photographs.
- Present a clear recoverable error.
- Allow retry after the user frees device storage or chooses another source.

If the database save fails:

- Roll back the dedicated context.
- Delete the canonical file.
- Report Add as failed.

If canonical cleanup fails after database rollback:

- Do not report Add as successful.
- Leave the managed canonical file as an orphan discoverable by
  reconciliation.
- Log the retryable cleanup failure locally.

The coordinator prevents reconciliation from inspecting or deleting the
canonical file after its move and before the metadata save completes.

### Add Crash States

- Crash before temporary creation: no persistent state.
- Crash during temporary write: managed temporary cleanup.
- Crash after temporary completion but before canonical move: managed temporary
  cleanup.
- Crash after canonical move but before metadata save: canonical orphan cleanup.
- Crash after metadata save: complete Photograph pair retained.

## Photograph Delete Transaction

The complete operation runs under one exclusive storage-coordinator permit and
uses a dedicated Photograph mutation context:

1. Resolve and validate the Photograph metadata and VisitHorse.
2. Derive the canonical URL from Photograph UUID.
3. Inspect the canonical item as a regular managed file.
4. If present, atomically move it to a unique quarantine path without
   overwriting.
5. Delete Photograph metadata.
6. Validate the current graph.
7. Save the dedicated SwiftData context.
8. After save succeeds, purge the quarantined file.

If the database save fails:

- Roll back the dedicated context.
- Atomically restore the quarantine file to its canonical path without
  overwriting.
- Report Delete as failed.

If restoration fails:

- Preserve metadata after rollback.
- Preserve the quarantine file.
- Report a recoverable deletion failure.
- Let reconciliation restore the file later.

If the database save succeeds but quarantine purge fails:

- Keep the Photograph user-visibly deleted.
- Preserve the managed quarantine file as retryable cleanup state.
- Let reconciliation purge it later.

If metadata exists but the canonical file is genuinely missing:

- Do not crash.
- Skip the quarantine move.
- Delete the broken metadata using the dedicated transaction.
- Do not require or fabricate a file.

### Delete Crash States

- Crash before quarantine move: complete Photograph pair retained.
- Crash after quarantine move but before metadata save: metadata plus one
  restorable quarantine file.
- Crash after metadata save but before purge: quarantine without metadata,
  eligible for purge.
- Crash after purge: Photograph fully deleted.

## Photo-Aware In-Progress Visit Discard

An in-progress Visit may own multiple VisitHorses and Photograph files. The
existing discard operation becomes photo-aware and runs under the same
exclusive storage-coordinator permit:

1. Resolve and validate the in-progress Visit and complete Photograph set.
2. Derive and inspect every canonical Photograph file.
3. Atomically move every present canonical file to a unique quarantine path.
4. Delete the Visit graph, allowing SwiftData cascades to remove VisitHorse and
   Photograph metadata.
5. Validate the resulting graph.
6. Save once in a dedicated context.
7. After save succeeds, purge every quarantine file.

If the database save fails:

- Roll back the dedicated context.
- Restore every quarantined file without overwriting.
- Report discard as failed.

Any failed restore or purge remains represented by surviving quarantine state
for reconciliation.

Completed Visits remain non-deletable.

### Visit Discard Crash States

- Crash before quarantine: complete Visit graph and files remain.
- Crash during quarantine: metadata remains; existing canonical files and
  quarantine candidates are reconciled conservatively.
- Crash after all quarantine moves but before save: metadata plus restorable
  quarantines.
- Crash after save but before purge: quarantines without metadata, eligible for
  purge.

## Reconciliation Preconditions

Reconciliation runs only after:

- Protected data is accessible.
- Photograph metadata fetch succeeds.
- Every managed directory is successfully enumerated.
- Every required entry is successfully inspected.
- Managed filenames are parsed without following symbolic links.

Reconciliation planning and execution both run under one uninterrupted
storage-coordinator permit.

Before mutating the filesystem, reconciliation builds a complete in-memory plan.
If metadata fetching, directory enumeration, required inspection, protected-data
access, or an unsafe ambiguity fails:

- Delete nothing.
- Move nothing.
- Preserve all metadata.
- Preserve every file.
- Log a retryable local reconciliation failure.

A protected-data access failure is not a missing-file result. Reconciliation is
deferred and retried after protected data becomes available.

## Reconciliation Rules

### Metadata and Canonical File Exist

- Confirm canonical item is a regular managed file.
- Retain metadata and canonical file.
- Purge stale managed quarantine copies only after canonical validity is
  confirmed.

### Metadata Exists, Canonical Is Missing, One Quarantine Exists

- Atomically restore the one valid managed quarantine file.
- Retain metadata.

### Metadata Exists, Canonical and Quarantine Are Missing

- Retain metadata.
- Expose the Photograph as unavailable.
- Allow explicit broken-metadata deletion.

### Metadata Exists With Multiple or Ambiguous Quarantines

- Restore nothing.
- Delete nothing during that failed reconciliation run.
- Log a retryable ambiguity.

### Quarantine Exists Without Metadata

- Purge the valid managed quarantine file.

### Interrupted Temporary File Exists

- Purge the valid managed temporary file.

### Canonical File Exists Without Metadata

- Purge the valid managed canonical orphan.

### Unknown Entry Exists

- Leave it untouched.
- Log it locally.

## Reconciliation Execution and Idempotence

After successful planning, apply the plan while retaining the exclusive permit.

If a cleanup or restoration step fails:

- Stop further execution safely.
- Preserve the surviving filesystem state.
- Log a retryable failure.
- Re-plan from actual state on the next run.

Filesystem presence is the crash-recovery record. Do not add:

- A cleanup journal.
- An operation-log SwiftData model.
- Persisted transaction states.
- A background task.

Reconciliation is idempotent. Re-running it against a consistent state produces
no additional mutations after the first successful run.

### Reconciliation Crash States

- Crash during planning: no mutation has occurred.
- Crash during execution: already completed moves or deletes leave a state
  classifiable by the same rules.
- Restart: acquire the exclusive permit, fetch and inspect again, build a new
  plan, and continue safely.

## Concurrency and Isolation

The feature follows the existing architectural direction:

```text
SwiftUI View
    ↓
@MainActor Photograph feature model
    ↓
PhotographStorageCoordinator
    ↓
Normalizer / File Store / Dedicated ModelContext
```

Feature-owned responsibilities:

- `PhotographStorageCoordinator`: exclusive operation ordering and permit
  lifetime.
- `PhotographNormalizer`: bounded decoding, orientation, sRGB rendering,
  resizing, encoding, and output validation.
- `PhotographFileStore`: managed URL derivation, file protection, capacity
  checks, collision-safe creation, moves, inspection, and enumeration.
- `PhotographReconciler`: fail-safe planning and idempotent execution through
  the coordinator.
- `PhotographImageLoader`: asynchronous read-only downsampling for display.
- Photograph feature models and views.

Image processing and display decoding occur away from SwiftUI rendering.
SwiftData contexts remain actor-correct and never cross concurrency boundaries.
Dedicated mutation contexts prevent rollback from affecting unrelated Visit
drafts or saves.

Production storage uses the application Application Support URL. Tests inject
temporary roots on the same volume as their temporary and quarantine
directories.

Do not add:

- A generalized repository.
- A dependency-injection framework.
- A global storage lock.
- A global task scheduler.
- A mutable singleton.
- A third-party package.

## Photograph Presentation

Each VisitHorse row shows its Photograph count and opens a dedicated native
Photograph collection.

The collection is reachable from:

- In-progress Visit editing.
- Completed Visit Detail.
- Completed Visit correction.
- Horse History through Visit Detail.

Photograph management remains available for Pending, Serviced, and Not Serviced
VisitHorses.

The collection provides:

- Native grid presentation.
- Camera action when available.
- System photo-picker action.
- Visible processing state.
- Full-image viewing.
- Explicit deletion confirmation.
- Unavailable representation for missing canonical files.
- Delete action for broken metadata.

Photograph add and delete operations save independently of the in-memory Visit
outcome draft. Cancelling unsaved outcome changes does not roll back a completed
Photograph operation.

The interface does not provide:

- Crop or rotation editing.
- Markup.
- Captions.
- Hoof classification.
- Before-or-after classification.
- Reordering.
- In-place replacement.
- Batch import.

## Image Display Reads

Display reads do not acquire the exclusive storage permit.

They:

- Derive the canonical URL from Photograph UUID.
- Inspect and read only the expected canonical regular file.
- Downsample with ImageIO to the requested display size.
- Use optional memory-only caching.
- Tolerate a file disappearing because a completed delete operation removed it.
- Render the Photograph's unavailable state rather than crashing.

No thumbnail file or thumbnail metadata is persisted.

## Missing-File Behavior

If Photograph metadata exists but its canonical file is genuinely missing:

- Do not crash.
- Do not silently hide the record.
- Do not fabricate an image.
- Show an unavailable Photograph entry.
- Allow explicit deletion of the broken metadata.
- Do not count it against the 16-available-Photograph limit.

Protected-data denial is not missing-file behavior and must not produce this
state.

## Accessibility and Field Readiness

- Keep Camera, Photo Library, and Delete actions at least 44 by 44 points.
- Support Dynamic Type without hiding primary actions or counts.
- Announce Photograph count and limit state.
- Announce each Photograph's position, app creation date, and availability.
- Give unavailable and processing states explicit text.
- Do not communicate availability, deletion, or errors by color alone.
- Preserve native navigation and confirmation behavior.
- Respect Reduce Motion and Increased Contrast.
- Keep common capture actions reachable with one hand.

## Error Handling

Surface recoverable errors for:

- Camera unavailable.
- Camera permission denied.
- Unsupported, invalid, zero-dimension, or undecodable source.
- Bounded decode failure.
- Color conversion failure.
- JPEG encoding or validation failure.
- Insufficient storage.
- UUID or file collision.
- File-protection denial.
- Atomic move failure.
- SwiftData validation or save failure.
- Rollback cleanup failure.
- Quarantine restoration failure.
- Missing canonical file.
- Unsafe managed entry.
- Ambiguous reconciliation state.
- Reconciliation inspection or execution failure.

Existing Photographs remain unchanged after a failed Add. A failed Delete either
retains the complete pair or leaves metadata plus recoverable quarantine state.
No failure produces success-shaped user feedback.

Use local structured logging for retryable cleanup and reconciliation failures.
Do not add telemetry or networking.

## Deterministic Concurrency Tests

Concurrency tests use injected test-controlled async suspension hooks or latches,
not timing-based sleeps.

Production hooks default to no-op and do not alter operation behavior.

Required suspension points include:

- Add after canonical move and before metadata save.
- Delete after quarantine move and before metadata save or restoration.
- Visit discard after quarantine and before graph save or restoration.
- Reconciliation after planning begins and before inspection or execution
  milestones needed by the tests.

Tests prove:

1. Reconciliation cannot inspect or purge files during an active Add.
2. Reconciliation cannot run during Delete quarantine, save, rollback, or
   restore.
3. Reconciliation cannot run during photo-aware Visit discard.
4. A second Add cannot bypass the 16-available-Photograph limit.
5. Serialization is released after every thrown failure.
6. A canonical file cannot be orphan-purged between its move and metadata save.
7. Waiting operations enter in coordinator order after the active permit is
   released.
8. Display reads tolerate a completed delete without requiring the exclusive
   permit.

The canonical-orphan race test suspends Add immediately after canonical move,
queues reconciliation, verifies that reconciliation has not reached inspection,
allows Add to save metadata, and then verifies reconciliation retains the valid
pair.

## Test and Verification Matrix

Run relevant coverage on iOS 18 and iOS 26.

### Schema and Migration

- V2-to-V3 migration.
- Chained V1-to-V2-to-V3 migration.
- No fabricated Photograph records, files, relationships, or placeholders.
- V1 and V2 graph preservation.
- V3 relationship inverses and delete rules.
- Optional storage and domain-required ownership behavior.

### Normalization

- Bounded downsampling of large sources.
- Upright orientation correction.
- Aspect-ratio preservation.
- No upscaling below 2560 pixels.
- 2560-pixel maximum longest edge.
- JPEG quality configuration at 0.82.
- sRGB output.
- Display P3 visual conversion.
- Opaque output.
- Source metadata stripping.
- Output reopening and validation.
- Invalid, zero-dimension, unsupported, and undecodable rejection.
- Byte-count accuracy.

### Storage and Limits

- Canonical URL derivation from UUID.
- No persisted path.
- No-overwrite file creation.
- UUID and file collision refusal.
- Complete file protection.
- Standard device-backup eligibility.
- Absence of a backup-exclusion resource value.
- Fifteen-to-sixteen available-Photograph boundary behavior.
- Missing files excluded from available count.
- Two concurrent Add attempts cannot bypass the limit.

### Transactions

- Successful Add.
- Add normalization failure.
- Add file-write failure.
- Add database rollback.
- Add rollback cleanup failure.
- Successful Delete.
- Delete database rollback.
- Delete restoration failure.
- Quarantine purge failure after successful Delete.
- Broken-metadata deletion without canonical file.
- Photo-aware Visit discard success.
- Visit discard rollback with multiple Photograph files.
- Visit discard restoration and purge failures.

### Reconciliation

- Metadata and canonical retention.
- Stale quarantine purge after canonical validation.
- Single quarantine restoration.
- Missing-file metadata retention.
- Ambiguous quarantine fail-safe behavior.
- Canonical orphan cleanup.
- Quarantine orphan cleanup.
- Interrupted temporary-file cleanup.
- Unknown-entry preservation.
- Malformed-name preservation.
- Directory preservation.
- Symbolic-link preservation without traversal.
- Protected-data access deferral.
- Directory-enumeration and inspection failure.
- Execution failure retryability.
- Idempotence.
- Mutual exclusion with Add, Delete, and Visit discard.

### Persistence and Interface

- Persistent store and file reopening.
- Photograph ownership after VisitHorse outcome correction.
- Deterministic Photograph ordering.
- Missing-file unavailable presentation.
- Broken-metadata deletion.
- Camera capture where available.
- Unavailable-camera behavior.
- Camera permission denial.
- System photo-picker import.
- Limit-reached state.
- Dynamic Type and VoiceOver behavior.
- Light Mode, Dark Mode, Increased Contrast, and Reduce Motion.

### Regression Gates

- Full unit and integration suites on iOS 18 and iOS 26.
- Relevant UI coverage on iOS 26.
- Focused iOS 18 compatibility UI coverage.
- Warning-free iOS 18 and iOS 26 builds.
- `git diff --check`.

## Exact Acceptance Flow

1. Open a multi-horse Appointment and start its Visit.
2. While one horse remains Pending, capture a camera Photograph.
3. Import a Photograph with the system picker for another scheduled horse.
4. Change both VisitHorse outcomes and verify Photograph ownership is unchanged.
5. Save Progress.
6. Terminate and relaunch.
7. Verify files, metadata, counts, and ownership.
8. Complete the Visit.
9. Open Photographs from Visit Detail and Horse History.
10. Correct an outcome and verify Photographs remain unchanged.
11. Delete one Photograph.
12. Add a new Photograph and verify its new UUID and creation date.
13. Terminate and relaunch.
14. Verify the complete V3 graph and normalized files persist.

## Explicit Exclusions

Slice 3 does not add:

- Visit-level Photograph ownership.
- Horse profile photographs.
- Unscheduled-horse photographs.
- Original-file retention.
- HEIC, RAW, or source-JPEG retention.
- Additional thumbnail files.
- Source filenames or asset identifiers.
- EXIF, GPS, device, or source timestamp metadata.
- Captions, hoof labels, or before-or-after classifications.
- Batch import.
- Crop, rotate, filter, or markup editing.
- In-place replacement.
- Version history.
- Persisted file paths.
- Cleanup journals or transaction-state models.
- Background tasks.
- Export or sharing.
- Networking, accounts, remote storage, or CloudKit.
- Synchronization or conflict resolution.
- App-managed backup or backup settings.
- Backup exclusion.
- Generalized storage repositories, locks, schedulers, or dependency injection.
- Third-party dependencies.

## Implementation Gate

This document authorizes specification review only.

Do not begin Slice 3 implementation or create the implementation plan until the
user approves this written specification.
