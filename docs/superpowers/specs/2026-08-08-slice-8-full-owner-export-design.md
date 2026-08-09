# Slice 8 — Full Owner Export Design

**Status:** Approved design

**Date:** 2026-08-08

## Purpose

Slice 8 gives the owner one complete, human-readable export of FarrierFlow's
current business records, invoice documents, and available hoof photographs.
The export is local, user-initiated, and portable outside FarrierFlow. It is not
a FarrierFlow backup, restore source, synchronization mechanism, or account
feature.

The export must preserve current and historical business truth without changing
the SwiftData graph, recompressing photographs, substituting current values for
invoice snapshots, or exposing persistence internals.

## Chosen Approach

Create one standards-based ZIP archive containing documented UTF-8 CSV tables,
invoice PDFs, canonical JPEGs, a human-readable README, and a JSON manifest.
Entries use ZIP's uncompressed storage method: JPEGs and PDFs are already
compressed, CSVs are small, and this keeps streaming, size preflight, and
cross-platform extraction deterministic. Present the finished ZIP with the
native system share sheet.

The archive is intentionally unencrypted. Before generation, FarrierFlow warns
that the archive contains private business and client information. This keeps
the result readable with ordinary tools without adding password handling,
custom encryption, or a third-party dependency.

### Alternatives Considered

1. **Standards-based ZIP — chosen.** One portable artifact works with common
   archive and spreadsheet tools across Apple and non-Apple platforms.
2. **Apple Archive — rejected.** It is native but does not provide the broad
   portability required for a human-readable owner export.
3. **Exported directory — rejected.** Its contents are readable, but saving and
   sharing a multi-file directory is less reliable than one standard archive.

## Product Boundary

- Export all entities and fields explicitly listed in the version-1 contract.
- Include every available canonical Photograph JPEG without recompression.
- Generate one PDF for every Invoice from immutable Invoice snapshots.
- Keep the complete operation offline.
- Create no export-history model or other persisted export state.
- Add no schema version or migration.
- Support no import or restore path.
- Offer one full-owner export, not filters or specialized report variants.
- Use no third-party dependency.

## User Flow and Lifecycle

- Add **Export Data** to Clients > More alongside other owner-level tools. Do
  not add a Settings screen or a new tab.
- The screen explains that the archive includes all current records, invoices,
  and available photographs; cannot be restored by FarrierFlow; and contains
  unencrypted private information.
- **Create Full Export** opens a native confirmation dialog.
- Generation shows determinate progress only where the total work is truthfully
  measurable, such as records prepared, photographs copied, and invoices
  rendered. Archive finalization may use an indeterminate native progress state
  when no meaningful completion percentage is available. No time estimate or
  fabricated percentage is shown.
- The owner can cancel generation. Cancellation stops work at the next safe
  cancellation boundary, removes all partial output, and leaves FarrierFlow
  data unchanged.
- When ready, the native share sheet opens.
- Completing or dismissing sharing removes the temporary archive.
- Failures provide a specific explanation and **Try Again**. Incomplete
  archives are never shared.
- Known-unavailable photographs do not block export, but their count is shown
  and recorded in `WARNINGS.txt`.
- Temporary content receives complete file protection and is cleaned after
  share completion or dismissal, cancellation, failure, or launch following
  interruption.
- Export remains offline and persists no export history.
- Native accessibility behavior covers progress, completion, Dynamic Type,
  VoiceOver, Reduce Motion, Increased Contrast, Light Mode, and Dark Mode.

## Architecture and Data Flow

- Introduce `Features/Export/` now that Slice 8 is shaped. It owns the export
  screen, route, immutable projections, CSV and manifest writers, temporary
  storage, ZIP creation, progress, cancellation, and sharing.
- `ClientListView` gains only an `ExportRoute`; no generalized Settings
  architecture is introduced. Source-mutation coordination is an app-composition
  persistence dependency described below, not navigation or Settings ownership.
- A `@MainActor @Observable ExportModel` controls UI state and coordinates one
  export operation at a time.
- An `ExportSnapshotBuilder` reads the shared SwiftData container through a
  main-actor-isolated boundary, validates required relationships, sorts every
  exported collection deterministically, and converts the complete current
  export graph into immutable `Sendable` export values. Snapshot construction
  must yield between bounded record groups so a large local store does not
  monopolize the main actor. SwiftData models and `ModelContext` never cross
  actors.
- `AppDependencies` creates one `PersistenceMutationCoordinator` beside the
  production `ModelContainer` and supplies that same coordinator explicitly to
  controlled persistence writers and `ExportSnapshotBuilder`. The coordinator
  owns only an in-memory opaque generation token and active-writer count. It is
  not a global singleton, service locator, repository, notification bus,
  persisted model, export-history record, or source of business data.
- Every production operation that inserts, deletes, or changes a SwiftData
  model enters a coordinator write scope synchronously before its first model
  mutation. The scope remains active across validation, save, rollback, and any
  operation-owned suspension points, and ends only after the context has
  reached its final success or failure state. Beginning and ending a write
  scope both replace the opaque generation token, so a write that starts and
  finishes between two export checks cannot disappear as a net-zero change.
  Preview and test fixture seeding that completes before an export begins is
  not a concurrent production writer.
- Snapshot construction begins only from a quiescent coordinator and captures
  its generation token. It validates that the coordinator remains quiescent
  and unchanged immediately after every cooperative suspension boundary,
  before every progress callback, and immediately before returning the
  immutable snapshot. No suspension occurs between the final validation and
  return. A writer is never delayed or rejected for export; if any writer
  begins while snapshot construction is active, export fails at the next safe
  boundary with a typed source-data-changed error and emits no later progress
  or shareable output.
- All app-owned record iteration used to establish or validate the snapshot is
  bounded by the approved batch size. The atomic generation checks are
  constant-time and must not be implemented by synchronously rescanning
  changed, inserted, deleted, or fetched model collections. Production code may
  not mutate the shared SwiftData graph outside a coordinator write scope.
- Snapshot creation is read-only and introduces no schema or migration change.
- The exact persisted entities included in a full export are defined by this
  contract rather than inferred dynamically from the schema. Adding a future
  persisted model does not silently add, omit, or change exported data without
  an explicit export-contract decision.
- The existing `PhotographLibrary` gains a focused export-copy boundary using
  its current storage coordinator. This prevents photograph add, delete, or
  reconciliation from racing with canonical JPEG copies. It never exposes
  unrestricted file-store mutation.
- After the immutable snapshot and required photograph copies are secured, an
  off-main export worker writes CSVs, manifests, warnings, and other filesystem
  output into a protected operation-specific staging directory. Invoice PDF
  generation uses the existing invoice-rendering isolation requirements. Any
  renderer that requires the main actor is invoked through that boundary rather
  than being assumed safe on the export worker.
- A small feature-owned ZIP encoder streams standard stored entries to disk. It
  does not load the entire archive into memory, add a dependency, or use Apple's
  less-portable archive format. It emits classic ZIP structures when all limits
  fit and ZIP64 structures when an entry size, archive offset, central-directory
  size, or entry count exceeds a classic limit. It must never truncate a value
  or emit a structurally invalid archive.
- Cancellation is checked between bounded record groups, photograph copies,
  invoice renders, file writes, and ZIP entries. Each is a safe boundary. An
  operation already performing an indivisible write or render finishes or fails
  before cleanup begins.
- ZIP entries are finalized with their required ZIP integrity metadata. Payload
  SHA-256 values and their algorithm are recorded explicitly in the manifest;
  the design does not refer ambiguously to an archive checksum.
- The archive is written under an operation-specific partial name and becomes
  shareable only after all required entries, the ZIP central directory, and
  manifest integrity metadata have been written successfully and the file has
  been closed successfully. Finalization atomically promotes the partial file
  to the shareable `.zip`.
- Temporary output is scoped by operation UUID. Cleanup is idempotent and may
  remove only strictly validated operation directories and files inside the
  Export-owned temporary root.
- File protection is applied when each staging file or directory is created,
  before sensitive content is written.
- App startup invokes only Export's orphan-cleanup boundary. It does not perform
  exports or scan unrelated temporary storage.
- Invalid required graph relationships, unavailable protected data,
  insufficient storage, serialization failure, PDF failure, or archive failure
  produce typed errors and remove the complete staging operation.
- A source mutation observed through the persistence coordinator during
  snapshot construction produces a typed source-data-changed error. The owner
  may retry after the write finishes; source records are never blocked,
  reverted, repaired, or partially exported.
- A Photograph metadata record whose canonical JPEG is already unavailable
  before export copying begins is the sole partial-success case. Its CSV row
  remains, the missing file is omitted, and the manifest and warnings identify
  it. A Photograph that becomes unreadable or fails unexpectedly during an
  otherwise protected export-copy operation fails the export rather than being
  silently reclassified as known unavailable.

## Archive Contract

The shareable filename is
`FarrierFlow-Export-yyyyMMdd'T'HHmmss'Z'.zip`, using its UTC creation time and
ASCII digits. The ZIP contains one `FarrierFlow Export` root directory with
this layout:

```text
FarrierFlow Export/
├── README.txt
├── manifest.json
├── WARNINGS.txt                 # only when warnings exist
├── Data/
│   ├── business-profile.csv
│   ├── clients.csv
│   ├── service-locations.csv
│   ├── horses.csv
│   ├── appointments.csv
│   ├── appointment-horses.csv
│   ├── visits.csv
│   ├── visit-horses.csv
│   ├── photographs.csv
│   ├── services.csv
│   ├── work-items.csv
│   ├── invoices.csv
│   ├── invoice-visits.csv
│   └── invoice-line-items.csv
├── Invoices/
│   └── Invoice-<number>.pdf
└── Photographs/
    └── <photograph-uuid>.jpg
```

### Version and Entity Scope

The export format begins at version `1`, independently of the SwiftData schema
version. Export-format compatibility is governed by this contract, not by
SwiftData schema numbering.

Version 1 includes exactly these persisted entities:

- `BusinessProfile`
- `Client`
- `Barn`
- `Horse`
- `Appointment`
- `AppointmentHorse`
- `Visit`
- `VisitHorse`
- `Photograph`
- `Service`
- `WorkItem`
- `Invoice`
- `InvoiceVisit`
- `InvoiceLineItem`

Future persisted entities or fields are not included automatically. Version 1
CSV schemas are closed. Adding, removing, renaming, reordering, or changing the
semantics of a version-1 CSV column requires a new export-format version. A
future persisted field may remain excluded without changing version 1, but
including that field in the exported data requires an explicit format-version
decision.

### CSV Column Contract

CSV column order is part of export format version 1. Every version-1 CSV
contains exactly the columns below, in exactly the listed order.

- `business-profile.csv`: `export_id`, `name`, `phone`, `email`, `address`,
  `default_invoice_note`, `default_appointment_duration_minutes`,
  `default_invoice_due_days`, `next_invoice_number`
- `clients.csv`: `export_id`, `name`, `phone`, `email`, `notes`
- `service-locations.csv`: `export_id`, `name`, `address`, `contact_notes`
- `horses.csv`: `export_id`, `name`, `safety_notes`,
  `appointment_interval_weeks`, `client_id`, `current_service_location_id`,
  `default_service_id`
- `appointments.csv`: `export_id`, `start_date_utc`, `start_date_local`,
  `notes`, `expected_duration_minutes`, `service_location_id`
- `appointment-horses.csv`: `export_id`, `appointment_id`, `horse_id`
- `visits.csv`: `export_id`, `started_at_utc`, `started_at_local`,
  `completed_at_utc`, `completed_at_local`,
  `service_location_name_snapshot`, `service_location_address_snapshot`,
  `appointment_id`, `service_location_id`
- `visit-horses.csv`: `export_id`, `outcome`, `work_notes`, `visit_id`,
  `horse_id`
- `photographs.csv`: `export_id`, `photograph_uuid`, `created_at_utc`,
  `created_at_local`, `pixel_width`, `pixel_height`, `byte_count`,
  `visit_horse_id`, `file_status`, `file_name`
- `services.csv`: `export_id`, `name`, `default_amount_minor_units`,
  `currency_code`, `default_amount_display`, `is_archived`
- `work-items.csv`: `export_id`, `service_name_snapshot`,
  `amount_minor_units`, `currency_code`, `amount_display`, `service_id`,
  `visit_horse_id`, `invoice_line_item_id`
- `invoices.csv`: `export_id`, `number`, `invoice_date_utc`,
  `invoice_date_local`, `due_date_utc`, `due_date_local`, `note`, `status`,
  `paid_at_utc`, `paid_at_local`, `client_name_snapshot`,
  `client_phone_snapshot`, `client_email_snapshot`, `business_name_snapshot`,
  `business_phone_snapshot`, `business_email_snapshot`,
  `business_address_snapshot`, `currency_code`, `client_id`, `pdf_file_name`
- `invoice-visits.csv`: `export_id`, `visit_date_snapshot_utc`,
  `visit_date_snapshot_local`, `service_location_name_snapshot`,
  `service_location_address_snapshot`, `invoice_id`, `source_visit_id`
- `invoice-line-items.csv`: `export_id`, `horse_name_snapshot`,
  `service_name_snapshot`, `amount_minor_units`, `currency_code`,
  `amount_display`, `invoice_visit_id`, `source_work_item_id`

`file_status` is exactly `available` or `unavailable`. An available Photograph
has a nonempty `file_name`; an unavailable Photograph has an empty `file_name`.
`outcome` is exactly `pending`, `serviced`, or `notServiced`. Invoice `status`
is exactly `unpaid` or `paid`. These values are the documented export-domain
values rather than arbitrary persisted raw strings.

To-many inverse collections are represented through the child or join CSVs and
are not serialized as delimited identifier lists. The optional
`invoice_line_item_id` in `work-items.csv` is included because it records the
one-to-one billed relationship from the source WorkItem. Other inverse
relationships can be recovered from their owning foreign-key columns without
duplicating collections.

### Identifier and Relationship Rules

- Every exported row receives a typed, export-local identifier such as
  `client-000001`, `horse-000001`, or `visit-000001`.
- The numeric portion is decimal, begins at one, and uses a minimum width of six
  digits without imposing a six-digit maximum.
- Relationship columns reference those identifiers. SwiftData
  `PersistentIdentifier` values and other persistence-internal identifiers are
  never serialized.
- Domain-required relationships always produce a nonempty relationship ID even
  when SwiftData storage is nullable for deletion compatibility. A missing or
  invalid required relationship fails export validation. Only genuinely
  domain-optional relationships may use an empty relationship cell.
- Export IDs are assigned after each entity collection is placed into a total
  deterministic order. Where exported domain values do not provide a final
  tie-breaker, persistence identity may be used internally only to establish
  ordering. It is never written to the archive.
- Export IDs remain consistent throughout one archive and are not promised to
  remain identical across separate exports.
- `Photograph.id` remains an approved persisted UUID scalar. The Photograph's
  export-local ID is separate; the persisted UUID is the canonical link to its
  exported JPEG filename.

### Scalar Representation

- Every persisted Date column listed in the version-1 contract has both its UTC
  and local-display column. When an optional Date is nil, both cells are empty.
- UTC values use `yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'`, with six fractional-second
  digits and literal `Z`, and are canonical. Local values are informational and
  use the export context recorded in the manifest.
- `manifest.json` records the IANA time-zone identifier, locale identifier, and
  calendar identifier used for local display values. Local date strings are
  never required to reconstruct an absolute timestamp.
- Money includes exact integer minor units and ISO currency code as its
  canonical representation. Locale-formatted display values are informational
  only and are never used for calculations.
- Optional scalar and domain-optional relationship values use empty CSV cells.
  Required relationships never silently become empty cells.
- Persisted enum raw values are validated against currently supported domain
  values before serialization. An unknown value fails export validation.
- Boolean values are the lowercase literals `true` and `false`.

### CSV Safety

- CSV files use UTF-8 encoding and CRLF record endings. A field containing a
  comma, double quote, carriage return, or line feed is surrounded by double
  quotes, and each embedded double quote is doubled.
- User-provided textual cells that could be interpreted as formulas by common
  spreadsheet applications are neutralized in the CSV representation.
- Neutralization prefixes one ASCII apostrophe to the original text when its
  first non-whitespace character is `=`, `+`, `-`, or `@`, or when its first
  character is a tab, carriage return, or line feed. The remaining original
  text is preserved and then escaped normally.
- Formula protection applies only to at-risk textual values. It does not modify
  numeric, identifier, currency, Boolean, or canonical date fields.
- `README.txt` documents the transformation and explains that CSV files are
  safe interchange representations rather than byte-for-byte persistence
  backups.
- Header-only CSV files remain present when a collection is empty so every
  version-1 archive has a predictable structure.

### Invoice and Photograph Files

- Invoice PDFs are generated exclusively from immutable `Invoice`,
  `InvoiceVisit`, and `InvoiceLineItem` snapshots. Current Client, Horse,
  Service, BusinessProfile, Visit, or WorkItem values cannot change historical
  invoice output.
- Invoice filenames use the immutable issued number and contain no Client or
  business names. The decimal number is left-padded to a minimum of four digits
  without truncating longer numbers; `pdf_file_name` stores its archive-relative
  path, such as `Invoices/Invoice-0001.pdf`.
- Photograph filenames use the persisted Photograph UUID, not Client, Horse,
  Visit, or Service Location names. UUID text is lowercase, and `file_name`
  stores its archive-relative path, such as
  `Photographs/01234567-89ab-cdef-0123-456789abcdef.jpg`.
- Available canonical JPEGs are copied byte for byte and never recompressed.
- `photographs.csv` supplies relationship context for photograph files.
- A known-unavailable Photograph remains represented in `photographs.csv`. Its
  JPEG is omitted, and warning information identifies it by Photograph export
  ID and persisted UUID without requiring names in the warning identifier.

### Manifest and Integrity

`manifest.json` records:

- export-format version;
- FarrierFlow app version and build;
- export creation timestamp in UTC;
- locale identifier;
- calendar identifier;
- IANA time-zone identifier;
- row count for every CSV;
- warning count; and
- a deterministic payload-file inventory.

The payload-file inventory contains every finalized regular archive file other
than `manifest.json` itself, in deterministic archive-relative path order. For
every payload file, the manifest records its archive-relative path, byte size,
and SHA-256 checksum. `manifest.json` is therefore excluded from its own
inventory, size, and checksum set. It makes no unsupported claim about a
whole-ZIP checksum. ZIP entry integrity remains part of the ZIP format, while
the manifest SHA-256 values provide explicit payload-file integrity
information. When `WARNINGS.txt` exists, it is included as a payload file like
any other finalized payload file.

No approved record field is selectively redacted. The explicit pre-export
privacy warning and confirmation are the privacy boundary for this
owner-controlled archive.

Derived UI state, transient drafts, navigation state, cached projections,
pre-existing generated PDF files, export history, internal SwiftData
identifiers, temporary filesystem paths, and other noncanonical implementation
state are not part of the export contract.

Every ZIP entry path is supplied by this fixed contract. The archive contains
no absolute paths, parent-directory components, symbolic links, hard links, or
filesystem metadata that could redirect extraction outside its root.

## Failure and Cancellation Semantics

- Source data is never mutated, repaired, or omitted to make export succeed.
- Invalid required relationships, invalid enum values, unavailable protected
  data, insufficient storage, serialization failure, invoice PDF failure,
  unexpected Photograph read or copy failure, ZIP failure, and finalization
  failure abort the complete operation.
- A known-unavailable Photograph identified before protected copying begins is
  the only warning-only partial-success condition.
- A successful archive is not visible to the share flow before atomic final
  promotion.
- Cancellation accepted at a documented safe boundary prevents any later
  promotion to shareable output.
- Cleanup runs after share completion or dismissal, cancellation, every failure,
  and next launch after interruption.
- Successfully finalized output remains available only for the lifetime
  required by the native system share flow.
- Cleanup validates every path and removes only Export-owned operation content.

## Verification

Verification must cover:

- Snapshot projection of every approved scalar and relationship across all 14
  entities.
- Coordinator coverage for every production SwiftData write entry point,
  including writers that use action-specific `ModelContext` instances.
- Rejection before initial progress when a writer is already active, plus
  rejection at the next safe boundary when a clean model, an already-dirty
  model, a forward relationship, or membership changes during snapshot work.
  Verification includes a writer that starts and finishes between export
  checks, an asynchronous writer spanning suspension points, and a captured
  insert-then-delete cycle whose public SwiftData pending state returns to its
  baseline.
- Constant-time generation validation and batch-bounded processing of any
  initial changed or deleted model collections; no unbounded app-owned scan is
  accepted as an atomicity substitute.
- Deterministic ordering and internally consistent typed export IDs.
- Required-versus-optional relationship handling and unknown-enum rejection.
- UTC and local date formatting, monetary representation, RFC 4180 escaping,
  Unicode, multiline text, and spreadsheet-formula neutralization.
- Header-only empty tables and manifest metadata.
- Immutable-snapshot invoice PDF generation.
- Byte-identical copying of available canonical JPEGs.
- Known-unavailable photograph warnings versus unexpected copy failure.
- SHA-256 manifest values, file sizes, inventory, and row counts.
- Classic ZIP and ZIP64 boundaries, central-directory integrity,
  truncated-write rejection, atomic promotion, and extraction with standard
  archive tools.
- Cooperative cancellation at every documented safe boundary, including the
  finalization boundary. Once cancellation is accepted, no archive may
  subsequently be promoted to shareable output.
- Insufficient storage, unavailable protected data, snapshot validation, PDF,
  serialization, Photograph, ZIP, and finalization failures.
- Complete file-protection attributes for operation directories, staged
  sensitive files, copied photographs, generated PDFs, and the finalized
  temporary ZIP, including protection before sensitive bytes are written.
- Complete cleanup after share completion or dismissal, cancellation, every
  injected failure, and simulated interrupted-export relaunch. Successfully
  finalized output remains available only for the native share-flow lifetime.
- Strict cleanup-path validation proving unrelated temporary content cannot be
  removed.

## Exact Acceptance Flow

1. Create a representative full graph containing owner profile and defaults,
   multiple Clients and Service Locations, Horses, scheduled and in-progress
   work, completed mixed-client Visits, WorkItems, active and archived Services,
   available photographs, unpaid and paid Invoices, and immutable historical
   snapshots.
2. Generate a full export and save it through the native system flow.
3. Extract it with a standard ZIP tool.
4. Verify every required file, CSV header, row count, relationship, PDF, JPEG,
   manifest entry, size, and SHA-256 value.
5. Confirm historical invoice output uses snapshots rather than current mutable
   records.
6. Generate a fixture containing a known-unavailable Photograph and verify
   warning-only success.
7. Cancel a large export during generation and verify cancellation is honored
   at the next documented safe boundary, no archive is promoted after
   cancellation has been accepted, and no shareable or partial output remains.
8. Inject each required failure and verify specific recovery behavior with no
   partial archive.
9. Relaunch and verify orphan cleanup, unchanged source records, and no
   persisted export history.
10. Complete VoiceOver, accessibility Dynamic Type, Reduce Motion, Increased
    Contrast, Light and Dark Mode, iOS 18, and iOS 26 verification.

## Explicit Exclusions

- Import, restore, migration, synchronization, backup, scheduled export, or
  background export.
- Incremental, filtered, per-client, or accountant-specific exports.
- Encryption or password handling.
- Network upload, email integration, or destination-specific APIs beyond the
  system share sheet.
- Persisted export history or export-status models.
- SwiftData schema changes.
- Third-party dependencies.
- Mutation, repair, or omission of source business records during export.
- A generalized repository, global persistence singleton, notification event
  bus, or export-owned lock that delays ordinary business-record writes.
