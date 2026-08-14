# Slice 8 — Full Owner Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `superpowers:test-driven-development` for every unit and
> `superpowers:verification-before-completion` before reporting a unit or the
> slice complete. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner create one offline, human-readable, standards-based ZIP
containing the complete approved FarrierFlow V1 export graph, invoice PDFs, and
available canonical hoof photographs without changing source data or adding a
restore path.

**Architecture:** Add one feature-owned Export pipeline. A main-actor snapshot
builder validates and freezes the explicit 14-entity SwiftData graph into
immutable Sendable values; existing photograph coordination secures byte-exact
media copies; off-main writers create protected CSV, PDF, manifest, and stored
ZIP/ZIP64 output. One observable model exposes truthful progress, cooperative
cancellation, atomic publication, native sharing, and cleanup.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, Observation, SwiftData,
Foundation, CryptoKit SHA-256, UIKit PDF/share APIs, Swift Testing/XCTest, iOS
18.0 minimum, latest stable iOS 26 SDK, no third-party dependencies.

## Execution Status

- Unit 1 — Closed V1 Format and CSV Encoding is complete, verified, and pushed
  to `origin/main` through
  `3ca14a428037e117f22d551b8f0eb5f73e171ce5`.
- Unit 2 — Complete SwiftData Snapshot is complete, verified, and pushed to
  `origin/codex/slice-8-unit-2-export-snapshot` through
  `884a908e4c481021394660c06e8c08a303fcb1e7`.
- Unit 3 — Protected Temporary Storage and Cleanup has not started and requires
  separate explicit approval before implementation.
- Units 4 through 8 have not started and remain dependent on their preceding
  units.

The per-unit checkboxes below preserve the approved implementation sequence;
current execution truth is recorded in this section, the corresponding commits,
and `.agents/workflow/CURRENT_UNIT.md` rather than inferred from checkbox state.

## Global Constraints

- The authoritative contract is
  `docs/superpowers/specs/2026-08-08-slice-8-full-owner-export-design.md`.
  Do not alter it during implementation unless a concrete contradiction or
  blocker is discovered and reported.
- Do not begin any unit until the user explicitly approves that unit and its
  exact scope is recorded in `.agents/workflow/CURRENT_UNIT.md`.
- Implement one unit, verify it, audit it, commit it locally, and stop at the
  repository's push/next-unit approval gates.
- Do not modify any file in `FarrierFlow/Core/Persistence/Schema/`,
  `CurrentSchema.swift`, or `ModelContainerFactory.swift`. Slice 8 adds no
  model, field, schema version, migration, or persisted export history.
- Preserve the closed export-format version 1 entity, column, order, enum,
  path, identifier, date, money, formula-neutralization, and manifest contract
  exactly.
- Keep SwiftData and `ModelContext` on the main actor. Only immutable Sendable
  export values cross to off-main work.
- Snapshot construction yields between bounded groups of at most 200 records.
- Apply `.complete` file protection to every operation directory and empty
  destination file before sensitive bytes are written.
- Use standard stored ZIP entries. Emit ZIP64 whenever any classic entry-size,
  offset, central-directory-size, or entry-count limit is exceeded.
- Cancellation is cooperative only at documented safe boundaries. Once
  accepted, it prevents atomic promotion to shareable output.
- A Photograph known unavailable before protected copying is the sole
  warning-only case. Any unexpected read/copy failure aborts the export.
- Use only fixed archive-relative paths. Write no absolute path, `..`, symbolic
  link, hard link, or source filesystem metadata into the archive.
- Use native `NavigationStack`, `Form` or `List`, `Section`, `ProgressView`,
  `confirmationDialog`, `sheet`, and `alert`. Add no tab, Settings screen,
  custom navigation, custom progress control, card dashboard, or background
  export.
- Add no import, restore, migration, synchronization, backup, scheduling,
  incremental/filter/per-client/accountant export, encryption/password flow,
  network/email/destination-specific integration, persisted export history,
  third-party dependency, or source-record mutation/repair/omission.
- New files are discovered by the existing synchronized Xcode groups. Do not
  edit `project.pbxproj` unless a build proves discovery is broken.
- Run every Xcode command serially with one destination, parallel testing
  disabled, and one test worker. Before each command run separately:

  ```bash
  pgrep -fl 'xcodebuild|xctest|XCTRunner'
  memory_pressure
  sysctl vm.swapusage
  ```

- Reuse these verified destinations unless they no longer exist:

  ```bash
  IOS18_DESTINATION='platform=iOS Simulator,id=02DB4E38-DF46-4F30-A8C8-C4D4DF46FDA4'
  IOS26_DESTINATION='platform=iOS Simulator,id=A9501C1D-4747-4310-8F2B-F0587E0E30C6'
  ```

- Every unit ends with `git diff --check`, a complete scoped diff audit, and an
  explicit staged-diff audit. Never stage `.agents/workflow/CURRENT_UNIT.md`.
- Do not push, begin the next unit, or start implementation beyond the
  currently approved unit without separate user authorization.

## File and Dependency Map

```text
Unit 1  Export-format values, fixed CSV projection, and CSV encoding
   ↓
Unit 2  Main-actor SwiftData snapshot of all 14 entities

Unit 3  Protected temporary storage, file writing, promotion, and cleanup
   ↓
Unit 4  PhotographLibrary export-copy boundary

Unit 5  Stored ZIP and ZIP64 writer

Units 1–5
   ↓
Unit 6  Manifest, payload digests, invoice rendering, and archive coordinator
   ↓
Unit 7  Export route, observable UI model, native screen/share flow, startup cleanup
   ↓
Unit 8  Full fixture, acceptance, relaunch, accessibility, platform gates, docs closure
```

No unit creates placeholder source for a later unit. A unit may add only the
interfaces its own tests exercise and the next dependency consumes.

---

## Unit 1 — Closed V1 Format and CSV Encoding

**Goal:** Encode the approved version-1 tables deterministically and safely
without SwiftData or filesystem dependencies.

**Files**

- Create `FarrierFlow/Features/Export/Models/ExportFormatV1.swift`.
- Create `FarrierFlow/Features/Export/Models/ExportSnapshot.swift`.
- Create `FarrierFlow/Features/Export/Models/ExportFormatError.swift`.
- Create `FarrierFlow/Features/Export/CSV/ExportCSVCell.swift`.
- Create `FarrierFlow/Features/Export/CSV/ExportCSVWriter.swift`.
- Create `FarrierFlow/Features/Export/CSV/ExportCSVProjector.swift`.
- Create `FarrierFlow/Features/Export/ExportValueFormatter.swift`.
- Create `FarrierFlowTests/Features/Export/ExportFormatV1Tests.swift`.
- Create `FarrierFlowTests/Features/Export/ExportCSVWriterTests.swift`.
- Create `FarrierFlowTests/Features/Export/ExportCSVProjectorTests.swift`.

**Interfaces**

```swift
nonisolated enum ExportFormatV1 {
    static let version = 1
    static let rootDirectory = "FarrierFlow Export"
    static let csvDefinitions: [ExportCSVDefinition]
}

nonisolated enum ExportEntity: String, Sendable, CaseIterable {
    case businessProfile = "business-profile"
    case client
    case serviceLocation = "service-location"
    case horse
    case appointment
    case appointmentHorse = "appointment-horse"
    case visit
    case visitHorse = "visit-horse"
    case photograph
    case service
    case workItem = "work-item"
    case invoice
    case invoiceVisit = "invoice-visit"
    case invoiceLineItem = "invoice-line-item"
}

nonisolated struct ExportCSVDefinition: Sendable, Equatable {
    let relativePath: String
    let columns: [String]
}

nonisolated enum ExportCSVCell: Sendable, Equatable {
    case empty
    case raw(String)
    case userText(String)
}

nonisolated struct ExportCSVTable: Sendable, Equatable {
    let definition: ExportCSVDefinition
    let rows: [[ExportCSVCell]]
}

nonisolated struct ExportContext: Sendable, Equatable {
    let createdAt: Date
    let localeIdentifier: String
    let calendarIdentifier: Calendar.Identifier
    let timeZoneIdentifier: String
}

nonisolated struct ExportSnapshot: Sendable, Equatable {
    let context: ExportContext
    let businessProfiles: [BusinessProfileExportRecord]
    let clients: [ClientExportRecord]
    let serviceLocations: [ServiceLocationExportRecord]
    let horses: [HorseExportRecord]
    let appointments: [AppointmentExportRecord]
    let appointmentHorses: [AppointmentHorseExportRecord]
    let visits: [VisitExportRecord]
    let visitHorses: [VisitHorseExportRecord]
    let photographs: [PhotographExportRecord]
    let services: [ServiceExportRecord]
    let workItems: [WorkItemExportRecord]
    let invoices: [InvoiceExportRecord]
    let invoiceVisits: [InvoiceVisitExportRecord]
    let invoiceLineItems: [InvoiceLineItemExportRecord]
    let invoiceDocuments: [ExportInvoiceDocument]
}

nonisolated struct ExportInvoiceDocument: Sendable, Equatable {
    let invoiceID: ExportRecordID
    let relativePath: String
    let content: InvoicePDFContent
}

nonisolated enum PhotographExportFileResult: Sendable, Equatable {
    case copied(relativePath: String, byteCount: Int64)
    case unavailable
}

nonisolated struct ExportCSVWriter {
    func encode(_ table: ExportCSVTable) throws -> Data
}

nonisolated enum ExportCSVProjector {
    static func tables(
        from snapshot: ExportSnapshot,
        photographResults: [UUID: PhotographExportFileResult]
    ) throws -> [ExportCSVTable]
}

nonisolated enum ExportValueFormatter {
    static func utc(_ date: Date) -> String
    static func local(_ date: Date, context: ExportContext) -> String
    static func boolean(_ value: Bool) -> String
    static func usdDisplay(minorUnits: Int64, localeIdentifier: String) -> String?
}
```

`ExportSnapshot.swift` defines one explicit Sendable, Equatable record struct
per approved CSV. Each property follows the exact column contract; relationship
values are typed `ExportRecordID` values rather than raw persistence IDs.
`PhotographExportRecord` carries its persisted UUID and metadata but receives
`file_status` and `file_name` only when `ExportCSVProjector` consumes secured
copy results.

**TDD and implementation steps**

- [ ] Add a failing `ExportFormatV1Tests` assertion containing the exact 14
  relative paths and exact ordered column arrays copied from the approved spec.

  ```swift
  @Test func versionOneTablesAreClosedAndOrdered() {
      #expect(ExportFormatV1.version == 1)
      #expect(ExportFormatV1.csvDefinitions.count == 14)
      #expect(
          ExportFormatV1.csvDefinitions.first == ExportCSVDefinition(
              relativePath: "Data/business-profile.csv",
              columns: [
                  "export_id", "name", "phone", "email", "address",
                  "default_invoice_note",
                  "default_appointment_duration_minutes",
                  "default_invoice_due_days", "next_invoice_number",
              ]
          )
      )
  }
  ```

- [ ] Run the new format test and confirm it fails because
  `ExportFormatV1` does not exist.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ExportFormatV1Tests
  ```

- [ ] Implement the 14 closed definitions and the explicit record/value types.
  Use minimum-six-digit typed IDs and keep stored relationship IDs nonempty by
  construction.

  ```swift
  nonisolated struct ExportRecordID: Sendable, Hashable, Equatable {
      let entity: ExportEntity
      let ordinal: Int

      var value: String {
          "\(entity.rawValue)-\(String(format: "%06d", ordinal))"
      }
  }
  ```

- [ ] Add failing CSV writer cases for CRLF, commas, quotes, multiline Unicode,
  empty cells, and formula-leading text after whitespace.

  ```swift
  @Test func protectsFormulaTextAndUsesCRLF() throws {
      let table = ExportCSVTable(
          definition: .init(relativePath: "Data/clients.csv", columns: ["name"]),
          rows: [[.userText("  =2+2")], [.userText("O\"Brien, LLC")]]
      )
      let output = try #require(String(data: ExportCSVWriter().encode(table), encoding: .utf8))
      #expect(output == "name\r\n'  =2+2\r\n\"O\"\"Brien, LLC\"\r\n")
  }
  ```

- [ ] Implement CSV encoding. Prefix one apostrophe before the complete
  original at-risk text, then apply RFC-style quoting; never formula-protect
  `.raw` numeric, identifier, Boolean, currency, or canonical-date cells.

- [ ] Add formatter tests for the exact six-digit UTC representation, local
  rendering with explicit locale/calendar/time zone, `true`/`false`, exact
  minor units, and informational USD display.

  ```swift
  @Test func writesCanonicalUTCWithSixFractionDigits() throws {
      let date = Date(timeIntervalSince1970: 1_725_000_000.123456)
      #expect(ExportValueFormatter.utc(date) == "2024-08-30T06:40:00.123456Z")
  }
  ```

- [ ] Add projector tests that instantiate all 14 record arrays, verify every
  row matches the fixed header width, verify header-only empty tables, verify
  supported enum values, and verify available/unavailable Photograph columns.

- [ ] Implement `ExportCSVProjector` with one explicit projection function per
  table. Reject an unsupported Visit outcome, Invoice status, currency, missing
  Photograph result, or row/header width mismatch with a typed
  `ExportFormatError`.

- [ ] Run all Unit 1 suites serially and confirm they pass.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ExportFormatV1Tests \
    -only-testing:FarrierFlowTests/ExportCSVWriterTests \
    -only-testing:FarrierFlowTests/ExportCSVProjectorTests
  ```

- [ ] Run `git diff --check`, audit only Unit 1 paths, stage those paths, inspect
  `git diff --cached --check` and the complete cached diff, then commit
  `feat(export): define version one archive tables`.

**Manual verification:** Not required; this unit has no user-facing flow or
filesystem mutation.

---

## Unit 2 — Complete SwiftData Snapshot

**Goal:** Validate and freeze the explicit current 14-entity graph into Unit
1's immutable export values without leaking SwiftData models across actors.

**Dependencies:** Unit 1 committed and approved to build upon.

**Files**

- Create `FarrierFlow/Features/Export/ExportSnapshotBuilder.swift`.
- Create `FarrierFlow/Features/Export/ExportSnapshotError.swift`.
- Create `FarrierFlowTests/Features/Export/ExportSnapshotBuilderTests.swift`.
- Create `FarrierFlowTests/Support/ExportTestFixtures.swift` for the reusable
  full-export graph used by later Export suites.
- Modify `FarrierFlowTests/Support/ModelFixtures.swift` only if one existing
  primitive needs a narrowly reusable parameter.

**Interface**

```swift
@MainActor
enum ExportSnapshotBuilder {
    static func build(
        in context: ModelContext,
        exportContext: ExportContext,
        batchSize: Int = 200,
        progress: @escaping @MainActor (ExportSnapshotProgress) -> Void
    ) async throws -> ExportSnapshot
}

nonisolated struct ExportSnapshotProgress: Sendable, Equatable {
    let completedRecords: Int
    let totalRecords: Int
}
```

**TDD and implementation steps**

- [ ] Build a failing representative graph test containing every model,
  optional value, required relationship, supported enum, mixed-client Visit,
  archived Service, paid and unpaid Invoice, Photograph metadata, and one
  billed WorkItem.

  ```swift
  @Test @MainActor
  func projectsEveryApprovedEntityAndRelationship() async throws {
      let fixture = try ExportTestFixtures.makeCompleteGraph()
      let snapshot = try await ExportSnapshotBuilder.build(
          in: fixture.context,
          exportContext: fixture.exportContext,
          progress: { _ in }
      )
      #expect(snapshot.clients.count == 2)
      #expect(snapshot.photographs.count == 1)
      #expect(snapshot.invoices.count == 2)
      #expect(snapshot.invoiceLineItems.first?.sourceWorkItemID != nil)
  }
  ```

- [ ] Run the new suite and confirm it fails because the builder is absent.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ExportSnapshotBuilderTests
  ```

- [ ] Implement bounded fetch/projection groups. Fetch each explicit model type,
  map at most `batchSize` records before `Task.checkCancellation()` and
  `Task.yield()`, total-sort intermediate values, assign typed IDs, then resolve
  relationship IDs. Do not reflect over `CurrentSchema.models`.

- [ ] Build `InvoicePDFContent` while still on the main actor from each
  Invoice's immutable snapshots and append one `ExportInvoiceDocument` to the
  snapshot. Keep `InvoiceExportRecord` limited to the closed CSV fields. Reuse
  `InvoiceDomainRules` validation and formatting; never read current source
  display values for PDF content.

- [ ] Add failure tests for each domain-required missing relationship, broken
  inverse, duplicate unique relationship, unknown outcome/status, invalid paid
  state, negative money, inconsistent currency, invalid Invoice sequence, and
  duplicate Photograph UUID. Each case must throw a specific
  `ExportSnapshotError` before output work starts.

- [ ] Add deterministic-order tests with equal user-visible values. Build twice
  from the unchanged context and assert identical snapshots while asserting no
  serialized value contains `String(describing: persistentModelID)`.

- [ ] Add a `batchSize: 1` test that records progress callbacks and proves
  cancellation is accepted between bounded groups without returning a partial
  snapshot.

- [ ] Run the focused suite and confirm all snapshot, validation, ordering, and
  cancellation cases pass.

- [ ] Run `git diff --check`, audit only Unit 2 paths, stage them explicitly,
  inspect the complete staged diff, and commit
  `feat(export): project the complete business graph`.

**Manual verification:** Not required; persistent-source integrity is covered
by focused tests and Unit 8 reopening gates.

---

## Unit 3 — Protected Temporary Storage and Cleanup

**Goal:** Establish the only filesystem boundary allowed to create, finalize,
promote, or remove Export-owned temporary content.

**Files**

- Create `FarrierFlow/Features/Export/Files/ExportOperationPaths.swift`.
- Create `FarrierFlow/Features/Export/Files/ExportTemporaryStore.swift`.
- Create `FarrierFlow/Features/Export/Files/ExportProtectedFileWriter.swift`.
- Create `FarrierFlow/Features/Export/Files/ExportFileError.swift`.
- Create `FarrierFlowTests/Features/Export/ExportTemporaryStoreTests.swift`.
- Create `FarrierFlowTests/Features/Export/ExportProtectedFileWriterTests.swift`.

**Interfaces**

```swift
nonisolated struct ExportOperationPaths: Sendable, Equatable {
    let operationID: UUID
    let operationDirectory: URL
    let payloadRoot: URL
    let partialArchive: URL
    let finalArchive: URL
}

nonisolated struct ExportTemporaryStore: Sendable {
    init(rootURL: URL = FileManager.default.temporaryDirectory.appending(
        path: "FarrierFlowExports",
        directoryHint: .isDirectory
    ), capacityProvider: @escaping @Sendable (URL) throws -> Int64? = ExportTemporaryStore.systemCapacity)

    func createOperation(id: UUID, archiveName: String) throws -> ExportOperationPaths
    func promote(_ paths: ExportOperationPaths) throws -> URL
    func removeOperation(_ paths: ExportOperationPaths) throws
    func removeOrphanedOperations() throws
    func availableCapacityForImportantUsage() throws -> Int64?
    static func systemCapacity(_ url: URL) throws -> Int64?
}

nonisolated struct ExportProtectedFileWriter: Sendable {
    init(
        beforeBytesWritten: @escaping @Sendable (URL) throws -> Void = { _ in }
    )

    func write(_ data: Data, to destination: URL) throws
    func copyExactly(from source: URL, to destination: URL) throws -> Int64
    func openEmptyProtectedFile(at destination: URL) throws -> FileHandle
}
```

**TDD and implementation steps**

- [ ] Write failing path tests proving the root and operation directory use
  only fixed names/lowercase UUIDs, partial and final names stay inside one
  operation, and invalid archive names, symlinks, `..`, or outside URLs fail.

- [ ] Write failing protection tests that inspect the directory and zero-byte
  destination before any payload bytes are written. On Simulator accept nil or
  `.complete`; on device require `.complete`, following Photograph tests.

  ```swift
  @Test func destinationIsProtectedBeforeWriteClosureRuns() throws {
      let recorder = FileProtectionRecorder()
      let writer = ExportProtectedFileWriter(beforeBytesWritten: recorder.record)
      try writer.write(Data("private".utf8), to: destination)
      #expect(recorder.value == nil || recorder.value == .complete)
  }

  private final class FileProtectionRecorder: @unchecked Sendable {
      private let lock = NSLock()
      private var storedValue: URLFileProtection?

      var value: URLFileProtection? { lock.withLock { storedValue } }

      func record(_ url: URL) throws {
          let value = try url.resourceValues(forKeys: [.fileProtectionKey])
              .fileProtection
          lock.withLock { storedValue = value }
      }
  }
  ```

- [ ] Implement strict containment using standardized file URLs plus regular
  file/directory and non-symlink checks. Never remove the root itself, unknown
  entries, malformed names, or paths supplied by callers outside the root.

- [ ] Implement protected directory creation and empty-file creation before
  `FileHandle` writes. `copyExactly` streams fixed-size chunks, closes both
  handles on every path, and verifies the copied count equals the source file
  size.

- [ ] Add atomic-promotion tests: close the partial file, reject an existing
  final destination, move on the same volume, prove the finalized temporary ZIP
  retains complete protection, and prove cancellation/failure cleanup leaves
  neither partial nor final output.

- [ ] Add orphan cleanup tests containing valid UUID operations, malformed
  entries, regular files at the root, directories outside the root, and
  symlinks. Remove only validated operation directories.

- [ ] Add capacity-provider tests for nil capacity, sufficient capacity, and
  mapped insufficient-space errors. Actual write ENOSPC remains mapped even
  when preflight reported sufficient space.

- [ ] Run both Unit 3 suites serially.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ExportTemporaryStoreTests \
    -only-testing:FarrierFlowTests/ExportProtectedFileWriterTests
  ```

- [ ] Run `git diff --check`, audit/stage only Unit 3 files, inspect the complete
  staged diff, and commit `feat(export): protect temporary archive files`.

**Manual verification:** Not required; protection, containment, promotion, and
cleanup are directly testable.

---

## Unit 4 — Serialized Photograph Export Copies

**Goal:** Copy canonical JPEGs byte for byte under the existing Photograph
storage coordinator while distinguishing known-unavailable assets from
unexpected failures.

**Dependencies:** Unit 3's protected writer.

**Files**

- Create `FarrierFlow/Features/Export/Files/PhotographExportCopy.swift`.
- Modify `FarrierFlow/Features/Photographs/PhotographLibrary.swift`.
- Modify `FarrierFlow/Features/Photographs/PhotographOperationHooks.swift` only
  to expose deterministic export-copy suspension points to tests.
- Create `FarrierFlowTests/Features/Export/PhotographExportCopyTests.swift`.
- Modify
  `FarrierFlowTests/Features/Photographs/PhotographConcurrencyTests.swift`.

**Interfaces**

```swift
nonisolated struct PhotographExportCopyRequest: Sendable, Equatable {
    let exportID: ExportRecordID
    let photographID: UUID
    let expectedByteCount: Int64
    let destinationURL: URL
}

extension PhotographLibrary {
    @MainActor
    func copyForExport(
        _ requests: [PhotographExportCopyRequest],
        writer: ExportProtectedFileWriter,
        progress: @escaping @MainActor (UUID, Int, Int) async throws -> Void
    ) async throws -> [UUID: PhotographExportFileResult]
}
```

**TDD and implementation steps**

- [ ] Add failing tests for zero requests, one available JPEG, lowercase UUID
  destination, byte identity, expected-byte-count mismatch, protected-data
  unavailability, and a canonical file already absent before copying.

  ```swift
  @Test @MainActor
  func knownMissingFileReturnsUnavailableWithoutCreatingDestination() async throws {
      let fixture = try PhotographExportFixture.make(metadataOnly: true)
      let results = try await fixture.library.copyForExport(
          [fixture.request],
          writer: fixture.writer,
          progress: { _, _, _ in }
      )
      #expect(results[fixture.photographID] == .unavailable)
      #expect(!FileManager.default.fileExists(atPath: fixture.request.destinationURL.path))
  }
  ```

- [ ] Implement one coordinator-held operation. Before any copy, inspect every
  request and freeze available versus known-unavailable status. Copy available
  regular nonsymlink files through `ExportProtectedFileWriter`; if a frozen
  available source later cannot be read or copied, throw and discard all
  results.

- [ ] Check cancellation between photograph copies, never relabel cancellation
  or an unexpected copy error as `.unavailable`, and emit truthful completed
  count plus the finished Photograph UUID after each copy. The throwing async
  progress boundary lets coordinator tests suspend, cancel, or inject failure
  without adding production delays.

- [ ] Add concurrency tests that suspend the export-copy operation and prove
  add, delete, Visit discard, and reconciliation wait on the same coordinator;
  prove a thrown copy failure releases the permit.

- [ ] Run the Export copy and Photograph concurrency suites serially.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/PhotographExportCopyTests \
    -only-testing:FarrierFlowTests/PhotographConcurrencyTests
  ```

- [ ] Run `git diff --check`, audit/stage only Unit 4 files, inspect the complete
  staged diff, and commit `feat(export): secure photograph archive copies`.

**Manual verification:** Not required; no UI entry exists and byte/protection/
serialization behavior is covered directly.

---

## Unit 5 — Stored ZIP and ZIP64 Writer

**Goal:** Produce structurally valid standard ZIP output without compression,
unbounded memory use, path traversal, or classic-limit truncation.

**Dependencies:** Unit 3's protected partial-file boundary.

**Files**

- Create `FarrierFlow/Features/Export/ZIP/ZIPCRC32.swift`.
- Create `FarrierFlow/Features/Export/ZIP/ZIPRecordEncoder.swift`.
- Create `FarrierFlow/Features/Export/ZIP/ZIPArchiveWriter.swift`.
- Create `FarrierFlow/Features/Export/ZIP/ZIPArchiveError.swift`.
- Create `FarrierFlowTests/Features/Export/ZIPCRC32Tests.swift`.
- Create `FarrierFlowTests/Features/Export/ZIPRecordEncoderTests.swift`.
- Create `FarrierFlowTests/Features/Export/ZIPArchiveWriterTests.swift`.
- Create `FarrierFlowTests/Support/ZIPTestReader.swift` as a test-only
  structural reader reused by Units 6 and 8.

**Interfaces**

```swift
nonisolated struct ZIPPayloadEntry: Sendable, Equatable {
    let relativePath: String
    let sourceURL: URL
    let byteCount: UInt64
    let crc32: UInt32
}

nonisolated struct ZIPEntryMetadata: Sendable, Equatable {
    let path: String
    let crc32: UInt32
    let byteCount: UInt64
    let localHeaderOffset: UInt64
}

nonisolated struct ZIPCentralDirectoryRecord: Sendable, Equatable {
    let data: Data
    let containsZIP64ExtraField: Bool
    let classicLocalHeaderOffset: UInt32
}

nonisolated enum ZIPRecordEncoder {
    static func centralDirectoryRecord(
        for metadata: ZIPEntryMetadata
    ) throws -> ZIPCentralDirectoryRecord
}

nonisolated struct ZIPArchiveWriter: Sendable {
    func write(
        entries: [ZIPPayloadEntry],
        to protectedPartialURL: URL,
        progress: @escaping @Sendable (String, Int, Int) async throws -> Void
    ) async throws
}
```

**TDD and implementation steps**

- [ ] Add CRC32 tests using the standard empty and `123456789` vectors and
  incremental chunks. Expected CRC32 for `123456789` is `0xCBF43926`.

- [ ] Add pure record-encoder tests for little-endian local headers, central
  records, UTF-8 path flag, stored method `0`, CRC/size fields, and end records.
  Supply synthetic metadata at `UInt32.max`, `UInt32.max + 1`, 65,535 entries,
  and 65,536 entries to test classic/ZIP64 selection without allocating huge
  files.

  ```swift
  @Test func offsetBeyondClassicLimitUsesZIP64ExtraField() throws {
      let metadata = ZIPEntryMetadata(
          path: "FarrierFlow Export/README.txt",
          crc32: 0,
          byteCount: 1,
          localHeaderOffset: UInt64(UInt32.max) + 1
      )
      let record = try ZIPRecordEncoder.centralDirectoryRecord(for: metadata)
      #expect(record.containsZIP64ExtraField)
      #expect(record.classicLocalHeaderOffset == UInt32.max)
  }
  ```

- [ ] Implement fixed-width checked little-endian writing. Reject empty,
  absolute, parent-traversing, duplicate, non-UTF-8, or contract-external paths.
  Never use truncating integer conversion.

- [ ] Add writer tests for deterministic path order, empty files, Unicode CSV
  bytes, multiple entries, source-size mismatch, CRC mismatch, write failure,
  and cancellation between entries. A finished indivisible entry may complete;
  the next header must not be written after cancellation is accepted. Report
  the completed entry path and truthful counts through the throwing async
  boundary so coordinator tests can suspend or inject failure deterministically.

- [ ] Implement streaming in bounded chunks from regular nonsymlink source
  files to the already-created protected partial file. Record local offsets and
  emit the central directory only after all entries finish.

- [ ] Validate a small produced archive structurally in tests by reading every
  local/central record and verifying payload bytes and CRCs. Reserve standard
  external-tool extraction for Unit 8 acceptance.

- [ ] Run all Unit 5 suites serially.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ZIPCRC32Tests \
    -only-testing:FarrierFlowTests/ZIPRecordEncoderTests \
    -only-testing:FarrierFlowTests/ZIPArchiveWriterTests
  ```

- [ ] Run `git diff --check`, audit/stage only Unit 5 files, inspect the complete
  staged diff, and commit `feat(export): write portable zip archives`.

**Manual verification:** Not required inside this unit; Unit 8 extracts a real
archive with standard tools.

---

## Unit 6 — Full Archive Coordination

**Goal:** Assemble one protected, internally consistent export and publish it
atomically only after all snapshot, media, document, manifest, and ZIP gates
succeed.

**Dependencies:** Units 1 through 5.

**Files**

- Create `FarrierFlow/Features/Export/Manifest/ExportManifest.swift`.
- Create `FarrierFlow/Features/Export/Manifest/ExportPayloadDigester.swift`.
- Create `FarrierFlow/Features/Export/ExportProgress.swift`.
- Create `FarrierFlow/Features/Export/ExportREADMEWriter.swift`.
- Create `FarrierFlow/Features/Export/ExportInvoiceDocumentWriter.swift`.
- Create `FarrierFlow/Features/Export/FullExportOperationHooks.swift`.
- Create `FarrierFlow/Features/Export/FullExportCoordinator.swift`.
- Create `FarrierFlow/Features/Export/FullExportError.swift`.
- Create `FarrierFlowTests/Features/Export/ExportManifestTests.swift`.
- Create `FarrierFlowTests/Features/Export/FullExportCoordinatorTests.swift`.

**Interfaces**

```swift
nonisolated struct ExportManifest: Codable, Sendable, Equatable {
    let exportFormatVersion: Int
    let appVersion: String
    let appBuild: String
    let createdAtUTC: String
    let localeIdentifier: String
    let calendarIdentifier: String
    let timeZoneIdentifier: String
    let rowCounts: [String: Int]
    let warningCount: Int
    let files: [PayloadFile]

    nonisolated struct PayloadFile: Codable, Sendable, Equatable {
        let path: String
        let byteCount: UInt64
        let sha256: String
    }

    static func make(
        context: ExportContext,
        appVersion: String,
        appBuild: String,
        rowCounts: [String: Int],
        warningCount: Int,
        payloads: [ExportPayloadDigest]
    ) throws -> ExportManifest
}

nonisolated enum ExportProgress: Sendable, Equatable {
    case records(completed: Int, total: Int)
    case photographs(completed: Int, total: Int)
    case invoices(completed: Int, total: Int)
    case finalizing
}

nonisolated struct FullExportResult: Sendable, Equatable {
    let archiveURL: URL
    let warningCount: Int
    let operationPaths: ExportOperationPaths
}

nonisolated struct ExportPayloadDigest: Sendable, Equatable {
    let relativePath: String
    let byteCount: UInt64
    let sha256: String
    let crc32: UInt32
}

nonisolated struct ExportPayloadDigester: Sendable {
    func digest(relativePath: String, fileURL: URL) throws -> ExportPayloadDigest
}

nonisolated struct ExportInvoiceDocumentWriter: Sendable {
    typealias Render = @Sendable (InvoicePDFContent) throws -> Data

    init(render: @escaping Render = { try InvoicePDFRenderer().render($0) })
    func write(
        _ document: ExportInvoiceDocument,
        to destination: URL,
        fileWriter: ExportProtectedFileWriter
    ) async throws
}

nonisolated enum FullExportStage: Sendable, Equatable {
    case operationCreated
    case snapshotFinished
    case photographFinished(UUID)
    case payloadFileWritten(relativePath: String)
    case invoiceFinished(ExportRecordID)
    case payloadDigested(relativePath: String)
    case manifestFinished
    case zipEntryFinished(relativePath: String)
    case beforePromotion
}

nonisolated struct FullExportOperationHooks: Sendable {
    let reached: @Sendable (FullExportStage) async throws -> Void
    static let production = FullExportOperationHooks(reached: { _ in })
}

@MainActor
final class FullExportCoordinator {
    init(
        temporaryStore: ExportTemporaryStore = .init(),
        fileWriter: ExportProtectedFileWriter = .init(),
        invoiceWriter: ExportInvoiceDocumentWriter = .init(),
        payloadDigester: ExportPayloadDigester = .init(),
        zipWriter: ZIPArchiveWriter = .init(),
        hooks: FullExportOperationHooks = .production
    )

    func generate(
        in context: ModelContext,
        photographLibrary: PhotographLibrary,
        exportContext: ExportContext,
        progress: @escaping @MainActor (ExportProgress) -> Void
    ) async throws -> FullExportResult

    func removeSharedResult(_ result: FullExportResult) throws
}
```

`ExportPayloadDigester` streams each finalized payload once and returns byte
size, SHA-256, and CRC32. Manifest JSON inventory is deterministic and excludes
`manifest.json`; the manifest itself still receives size/CRC metadata for ZIP
records but never enters its own payload inventory.

**TDD and implementation steps**

- [ ] Add manifest tests for every required context field, all 14 CSV row
  counts, deterministic path order, byte sizes, lowercase SHA-256 hex, warning
  count, `WARNINGS.txt` inclusion, and complete exclusion of `manifest.json`
  from inventory/size/checksum.

  ```swift
  @Test func manifestNeverInventoriesItself() throws {
      let manifest = try ExportManifest.make(
          context: fixture.context,
          appVersion: "1.0",
          appBuild: "1",
          rowCounts: fixture.rowCounts,
          warningCount: 0,
          payloads: fixture.payloads
      )
      #expect(!manifest.files.contains { $0.path == "FarrierFlow Export/manifest.json" })
  }
  ```

- [ ] Add coordinator RED tests using temporary roots, concrete writers, and
  `FullExportOperationHooks` suspension/failure points. Prove the exact
  successful call order and that the result URL does not exist before final
  promotion.

- [ ] Implement the pipeline in this order: create operation; snapshot; secure
  photographs; project/write all CSVs; render/write invoice PDFs; write README
  and conditional warnings; digest finalized payloads; write manifest; digest
  manifest for ZIP metadata only; capacity preflight for the stored ZIP; create
  protected partial ZIP; write ZIP; check cancellation at finalization; close;
  atomically promote; return result.

- [ ] Reuse `InvoicePDFRenderer` through a Sendable
  `ExportInvoiceDocumentWriter`. Render immutable `InvoicePDFContent` values
  off-main, then write PDF bytes through `ExportProtectedFileWriter`.

- [ ] Add failure-injection tests at every pipeline boundary, including each
  Photograph copy, CSV/PDF/README/warnings/manifest write, payload digest, ZIP
  entry, and promotion. Each test asserts no final archive, no partial archive,
  operation cleanup, unchanged source model counts/values, and the precise
  mapped `FullExportError`.

- [ ] Add cancellation tests for snapshot groups, between photographs, between
  every CSV and auxiliary file write, between invoices, between payload
  digests, between ZIP entries, and immediately before promotion. Reuse the
  lower-level Unit 2, 4, and 5 cancellation assertions, then prove the complete
  coordinator cleans its operation for every accepted cancellation. Once
  accepted, no result may appear even if an indivisible prior action finishes.

- [ ] Add an integration success test using a complete in-memory graph, real
  CSV/PDF/JPEG/digest/ZIP writers, fixed export context, and temporary roots.
  Parse the archive records to verify all fixed paths, header-only tables where
  applicable, manifest values, byte-identical JPEG, and PDF signature/content.
  Inspect complete protection on the operation directory, every staged CSV and
  text file, copied JPEG, rendered PDF, partial ZIP, and finalized temporary
  ZIP.

- [ ] Add the known-unavailable case and prove it alone succeeds with one
  warning, an empty Photograph file cell, no JPEG entry, and checksummed
  `WARNINGS.txt`.

- [ ] Run both Unit 6 suites serially.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ExportManifestTests \
    -only-testing:FarrierFlowTests/FullExportCoordinatorTests
  ```

- [ ] Run `git diff --check`, audit/stage only Unit 6 files, inspect the complete
  staged diff, and commit `feat(export): assemble full owner archives`.

**Manual verification:** Not required yet; the native presentation and actual
share lifecycle are Unit 7.

---

## Unit 7 — Native Export Screen and Share Lifecycle

**Goal:** Expose the completed coordinator through one accessible owner-level
screen with privacy confirmation, truthful progress, cancellation, retry,
native sharing, and startup orphan cleanup.

**Dependencies:** Unit 6.

**Files**

- Create `FarrierFlow/Features/Export/ExportRoutes.swift`.
- Create `FarrierFlow/Features/Export/ExportModel.swift`.
- Create `FarrierFlow/Features/Export/Views/ExportView.swift`.
- Create `FarrierFlow/Core/Utilities/FileShareSheet.swift`.
- Delete `FarrierFlow/Features/Invoices/Views/InvoiceShareSheet.swift` after
  replacing its sole use with `FileShareSheet`.
- Modify `FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift` only for
  the shared sheet rename.
- Modify `FarrierFlow/Features/Clients/Views/ClientListView.swift`.
- Modify `FarrierFlow/App/FarrierFlowApp.swift`.
- Modify `FarrierFlow/Resources/Localizable.xcstrings`.
- Create `FarrierFlowTests/Features/Export/ExportModelTests.swift`.
- Create `FarrierFlowUITests/ExportFlowUITests.swift`.
- Modify `FarrierFlowUITests/RootNavigationUITests.swift`.

**Interfaces**

```swift
enum ExportRoute: Hashable {
    case fullOwnerArchive
}

@MainActor @Observable
final class ExportModel {
    private(set) var progress: ExportProgress?
    private(set) var isGenerating = false
    private(set) var result: FullExportResult?
    var alert: FeatureAlert?

    init(coordinator: FullExportCoordinator = .init())

    func generate(
        in context: ModelContext,
        photographLibrary: PhotographLibrary,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone
    )
    func cancelGeneration()
    func sharingCompleted()
    func retry(
        in context: ModelContext,
        photographLibrary: PhotographLibrary,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone
    )
}
```

**TDD and implementation steps**

- [ ] Add model RED tests for idle state, one active operation, determinate
  records/photos/invoices states, indeterminate finalizing state, safe-boundary
  cancellation, retry after typed failure, warning success, share dismissal,
  and cleanup on model disappearance.

- [ ] Implement `ExportModel` with one owned `Task<Void, Never>`. Never allow a
  second operation while active. Map typed errors to specific copy, keep
  cancellation silent, and keep a finalized result only until the share sheet
  completion callback.

- [ ] Add **Export Data** to Clients > More and route to `ExportView`. The view
  uses native sections for included data, export-only explanation, and the
  unencrypted privacy warning; **Create Full Export** opens a visible native
  confirmation dialog.

- [ ] Present determinate `ProgressView(value:total:)` only for record,
  Photograph, and Invoice phases. Present `ProgressView()` for `.finalizing`.
  Provide **Cancel Generation**, **Try Again**, and VoiceOver progress values
  with stable accessibility identifiers.

- [ ] Generalize the existing one-URL `UIActivityViewController` wrapper to
  `FileShareSheet`, switch Invoice sharing to it without behavior change, and
  use it for the final ZIP. Both completion and sheet dismissal call cleanup
  exactly once.

- [ ] Invoke `ExportTemporaryStore.removeOrphanedOperations()` once during app
  startup. Log a privacy-safe cleanup error without blocking the local business
  app; the next launch retries. Do not start an export or scan outside Export's
  root.

- [ ] Add source strings to the catalog, then validate JSON and compile the
  string catalog to a unique temporary directory.

  ```bash
  jq empty FarrierFlow/Resources/Localizable.xcstrings
  STRING_OUTPUT_DIRECTORY="$(mktemp -d)"
  xcrun xcstringstool compile --dry-run \
    --output-directory "$STRING_OUTPUT_DIRECTORY" \
    FarrierFlow/Resources/Localizable.xcstrings
  /bin/rm -R "$STRING_OUTPUT_DIRECTORY"
  ```

- [ ] Extend root navigation UI coverage to assert **Export Data** exists and
  **Settings** still does not. Add focused Export UI coverage for explanation,
  privacy confirmation, generated share sheet, dismissal, and accessibility
  Dynamic Type. Keep safe-boundary cancellation and phase semantics in the
  deterministic `ExportModelTests`; do not slow production code for UI tests.

- [ ] Run the model tests, Invoice PDF share regression tests, and focused iOS
  26 UI tests serially.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ExportModelTests \
    -only-testing:FarrierFlowTests/InvoicePDFShareModelTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests/RootNavigationUITests \
    -only-testing:FarrierFlowUITests/ExportFlowUITests
  ```

- [ ] Manually verify iOS 26 navigation, privacy confirmation, cancellation,
  progress transitions, successful share dismissal, retry, VoiceOver, and
  accessibility XXXL. Confirm no output survives dismissal and source records
  remain visible.

- [ ] Shut down the used simulator and confirm no task-owned `xcodebuild`,
  `xctest`, or `XCTRunner` remains.

- [ ] Run `git diff --check`, audit/stage only Unit 7 files, inspect the complete
  staged diff, and commit `feat(export): add full archive sharing flow`.

---

## Unit 8 — Acceptance, Relaunch, and Slice Closure

**Goal:** Prove the complete design contract with a representative graph,
standard extraction, failure/cancellation fixtures, accessibility, persistent
reopening, and both supported platform generations before closing Slice 8.

**Dependencies:** Units 1 through 7.

**Files**

- Create `FarrierFlowTests/Features/Export/ExportAcceptanceTests.swift`.
- Modify `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`.
- Modify `FarrierFlow/App/UITestLaunchConfiguration.swift`.
- Modify `FarrierFlow/Core/Persistence/PreviewFixtures.swift`.
- Expand `FarrierFlowUITests/ExportFlowUITests.swift`.
- Update `PRODUCT.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, and `ROADMAP.md` only
  after all final gates pass.
- Update
  `docs/superpowers/specs/2026-08-08-slice-8-full-owner-export-design.md` and
  this plan only with directly evidenced completion status after all gates pass.

**TDD and implementation steps**

- [ ] Add a deterministic `fullExport` UI-test scenario containing owner
  defaults, two Clients, two Service Locations, multiple Horses, scheduled and
  in-progress work, a completed mixed-client Visit, active and archived
  Services, WorkItems, available JPEGs, one Unpaid and one Paid Invoice, and
  immutable historical snapshots. Keep fixture data test-only.

- [ ] Add an acceptance test that runs the real coordinator against the full
  graph and verifies all 14 CSV files and exact headers, every relationship,
  PDFs, JPEG bytes, manifest inventory/sizes/SHA-256, warning count, and source
  record equality before and after export.

- [ ] Add a persistent-store test that exports, releases the original container,
  reopens the store, and proves every source record/relationship is unchanged
  and no export model or history exists.

- [ ] Add final warning-only, unexpected Photograph failure, insufficient
  storage, protected-data, every writer failure, large-operation cancellation,
  finalization cancellation, orphan cleanup, and unrelated-temp survival cases.

- [ ] Run focused iOS 26 acceptance/reopening tests first and fix only concrete
  in-scope failures.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/ExportAcceptanceTests \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests
  ```

- [ ] Save one generated archive through the native share flow, retrieve it at
  a user-selected Files location, and validate/extract it with standard macOS
  tools. Use an explicit path selected for this check.

  ```bash
  SLICE8_ZIP_PATH='/Users/prometheus/Desktop/FarrierFlow-Slice8-Acceptance.zip'
  /usr/bin/unzip -t "$SLICE8_ZIP_PATH"
  SLICE8_EXTRACT_DIRECTORY="$(mktemp -d)"
  /usr/bin/ditto -x -k "$SLICE8_ZIP_PATH" "$SLICE8_EXTRACT_DIRECTORY"
  rg --files "$SLICE8_EXTRACT_DIRECTORY/FarrierFlow Export" | sort
  /bin/rm -R "$SLICE8_EXTRACT_DIRECTORY"
  ```

- [ ] Manually verify the exact full flow on iOS 26 with VoiceOver and
  accessibility XXXL: privacy explanation, confirmation, truthful determinate
  phases, indeterminate finalization, safe cancellation, successful share,
  warning count, dismissal cleanup, retry, and unchanged source records after
  relaunch. Verify Reduce Motion, Increased Contrast, Light Mode, and Dark Mode,
  then repeat a compatibility smoke flow on iOS 18.

- [ ] Run final serial iOS 18 and iOS 26 unit/integration suites.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -skip-testing:FarrierFlowUITests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -skip-testing:FarrierFlowUITests
  ```

- [ ] Run the focused iOS 18 Export UI flow, then the complete iOS 26 UI suite.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests/ExportFlowUITests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests
  ```

- [ ] Run persistent-reopening and schema-contract gates on iOS 18 and iOS 26.
  No migration test is added because the approved slice changes no schema;
  `SchemaContractTests` proves the 14-model shipping schema is unchanged.

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests \
    -only-testing:FarrierFlowTests/SchemaContractTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests \
    -only-testing:FarrierFlowTests/SchemaContractTests
  ```

- [ ] Build the app serially for iOS 18 and iOS 26 and require success without
  new project diagnostics.

  ```bash
  xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION"

  xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION"
  ```

- [ ] Validate the string catalog and final diff.

  ```bash
  jq empty FarrierFlow/Resources/Localizable.xcstrings
  STRING_OUTPUT_DIRECTORY="$(mktemp -d)"
  xcrun xcstringstool compile --dry-run \
    --output-directory "$STRING_OUTPUT_DIRECTORY" \
    FarrierFlow/Resources/Localizable.xcstrings
  /bin/rm -R "$STRING_OUTPUT_DIRECTORY"
  git diff --check
  ```

- [ ] Review the complete tracked and untracked diff against every approved
  Slice 8 requirement and exclusion. Correct findings, rerun affected focused
  gates, then repeat the complete audit.

- [ ] After every gate passes, update only directly evidenced completion status
  in the listed product/architecture/data/roadmap/spec/plan documents. Rerun
  `git diff --check` after the last documentation edit.

- [ ] Shut down both simulators, quit Simulator, and confirm no task-owned
  `xcodebuild`, `xctest`, or `XCTRunner` remains.

- [ ] Stage only Unit 8 acceptance/tests/closure paths, inspect
  `git diff --cached --stat`, `git diff --cached --name-status`,
  `git diff --cached --check`, and the complete cached diff. Commit
  `test(export): verify full owner archive` and stop for push authorization.

## Execution Handoff

Units 1 and 2 are complete at the commits recorded in **Execution Status**.
This plan does not authorize Unit 3. To begin Unit 3, the user must approve its
exact scope, branch, focused tests, and manual-verification requirement in
`.agents/workflow/CURRENT_UNIT.md`. Implementation must then use the required
execution and TDD skills and stop at every unit commit/push/next-unit gate.
