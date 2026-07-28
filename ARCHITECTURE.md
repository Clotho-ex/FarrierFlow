# FarrierFlow Architecture

## Architectural Goals

FarrierFlow is a local-first, iPhone-only SwiftUI application. Slice 1 proved
connected persistence, Slice 2 added Visit completion and Horse History, and
Slice 3 adds VisitHorse-owned photographs, bounded image normalization,
coordinated file-and-database mutations, and a tested V1-to-V2-to-V3 migration.
It adds no networking, CloudKit, or third-party dependency.

The dependency direction is:

```text
SwiftUI View
    ↓
@Observable feature model
    ↓
Domain rule or use case
    ↓
SwiftData ModelContext
```

Views render state and send user actions. Feature models coordinate screen
behavior. Pure business rules remain independent of view code. SwiftData is the
local source of truth.

## Source Organization

Active ownership through Slice 3 uses the approved feature-first structure:

```text
FarrierFlow/
├── App/
│   ├── FarrierFlowApp.swift
│   └── RootView.swift
├── Core/
│   ├── DesignSystem/
│   │   ├── ColorTokens.swift
│   │   ├── SpacingTokens.swift
│   │   └── Typography.swift
│   ├── Persistence/
│   │   ├── ModelContainerFactory.swift
│   │   ├── Schema/
│   │   └── Migrations/
│   ├── DateAndTime/
│   │   └── CalendarRules.swift
│   └── Utilities/
│       ├── FeatureAlert.swift
│       └── TextNormalization.swift
├── Features/
│   ├── Today/
│   ├── Schedule/
│   ├── Clients/
│   ├── Barns/
│   ├── Horses/
│   ├── Visits/
│   └── Photographs/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

This tree contains only active ownership through Slice 3. `Core/Utilities`
contains only utilities genuinely shared by active features with no clearer
domain owner. Later features such as services, invoices, payments,
export, subscriptions, backup, and Settings receive their own feature
ownership only after each capability is shaped. No empty directory or
destination is created for deferred work.

Within a feature, organize by responsibility:

```text
Features/Horses/
├── Models/
├── Views/
├── Components/
├── HorseListModel.swift
├── HorseEditorModel.swift
└── HorseRoutes.swift
```

A component stays inside its feature unless at least two features genuinely
share the same behavior and presentation. There is no global `ViewModels`
directory.

## App Composition

`FarrierFlowApp` creates the production `ModelContainer` and one
`PhotographLibrary`, then supplies both through SwiftUI's environment. The
small composition value owns the concrete Photograph file store and serial
coordinator; it is neither a mutable global singleton nor a service locator.

`RootView` owns the root `TabView` and the selected tab. It opens on Today and
contains three tabs:

1. Today
2. Schedule
3. Clients

Each tab owns a separate `NavigationStack` and path. Switching tabs therefore
does not discard navigation state or combine unrelated routes.

## Route and Presentation Ownership

- Today owns its list and Today-specific routes. Its add action presents the
  appointment editor owned by Schedule.
- Schedule owns appointment lists, appointment detail, appointment creation,
  and appointment editing.
- Visits owns Visit start, in-progress editing, progress saving, completion,
  correction, detail presentation, and Visit-specific validation.
- Photographs owns camera and picker ingestion, normalization, file storage,
  VisitHorse collections, deletion, and reconciliation.
- Clients owns client list, client detail, and client creation.
- Horses owns horse list/detail/editor behavior reached from client or
  service-location context.
- Barns owns the Service Locations list, service-location detail, and
  service-location editor.
- The Clients toolbar menu exposes only Service Locations through Slice 3.
  Service Locations is pushed within the Clients navigation stack.
- No Settings route, screen, folder, toolbar item, or empty destination exists
  through Slice 3. Settings may be introduced later only when concrete
  settings require a destination.

Appointment Detail owns the entry into Visits: Start Visit when none exists,
Resume Visit while in progress, and View Visit after completion. Visit Detail
is shared by Appointment Detail and Horse History. Horse Detail owns its
completed-history projection and routes to Visit Detail. No Visit tab or global
history destination is added.

The presenting feature owns sheet presentation state and any transient context,
such as a preselected client. The presented editor owns its draft, validation,
Save, and Cancel behavior. A nested service-location sheet returns the newly
created location to the horse editor without creating a persisted Client–Barn
relationship.

Navigation routes carry SwiftData persistent identifiers or small immutable
route values, not live `ModelContext` instances. A destination resolves the
record inside its current context and handles a missing record as an
unavailable state.

## State and Concurrency

Feature models that mutate interface state are `@MainActor @Observable`.
Examples include list coordination, editor drafts, validation messages,
selection, sheet state, and navigation actions.

Actor-neutral types include:

- Immutable domain values.
- Pure validation and normalization rules.
- Calendar calculations that receive an explicit `Calendar`.
- Persistence schema declarations that do not coordinate UI state.

Do not mark actor-neutral values `@MainActor` merely because a view consumes
them. Do not move `ModelContext` across actors. Persistence mutations initiated
by a feature model occur on the feature model's main-actor context.

Image normalization and display downsampling use bounded ImageIO work away from
SwiftUI rendering. SwiftData contexts stay on the main actor. One feature-owned
actor holds an explicit permit across every await in Photograph add, delete,
photo-aware Visit discard, and reconciliation. Image display reads remain
nonexclusive and tolerate completed deletion.

## Persistence Containers

`ModelContainerFactory` has explicit configurations:

- Production: a persistent on-disk store using the current versioned schema.
- Preview: an in-memory store populated only by preview-specific fixtures.
- Test: an in-memory store by default, with an explicit temporary on-disk
  configuration for store-reopening tests.

The app must fail visibly if the production container cannot be created. It
must not silently replace a failed durable store with an in-memory store.
Preview and test fixtures never enter production startup code.

The schema and migration plan live under `Core/Persistence`. V1 remains the
five-model connected-record snapshot, V2 the seven-model Visit snapshot, and V3
the current eight-model Photograph snapshot. The migration plan contains
lightweight V1-to-V2 and V2-to-V3 stages. Production keeps the existing store
identity and URL; a schema change must never create a replacement empty store.

## Domain and Persistence Boundaries

Views do not create fetch descriptors, insert models, save contexts, delete
records, or traverse persistence relationships to enforce business rules.
Feature models perform those operations directly through their `ModelContext`
or call a small domain use case when a rule is shared or independently
testable.

The active slices do not add a generalized repository layer. A focused
repository is justified only when a real persistence boundary cannot be
expressed clearly with `ModelContext`. There is no protocol around every
concrete type and no dependency-injection framework.

Deletion use cases perform relationship preflight checks, return a typed
blocked reason, and delete only when the approved rules allow it. SwiftData
relationship delete rules provide a second line of data protection.

### Persistence Storage Optionality and Domain Requiredness

SwiftData stores the required to-one relationships on `Horse`, `Appointment`,
and `AppointmentHorse` as optional so iOS 18 can nullify inverse references
safely during deletion. The domain contract remains required: a Horse must have
a Client and current Barn, an Appointment must have a Barn and at least one
valid join, and every AppointmentHorse must have both an Appointment and Horse.

V2 applies the same storage rule to `Visit.appointment`, `Visit.barn`,
`VisitHorse.visit`, and `VisitHorse.horse`. These relationships are optional in
SwiftData storage for iOS 18 deletion compatibility and required by the domain
contract. `Visit.startedAt` and its service-location name snapshot remain
non-optional scalar data; the address snapshot remains optional because a Barn
address is optional.

Editors and feature models require these selections, controlled creation paths
construct complete graphs, and complete-graph validation runs immediately
before every save. It rejects missing relationships, a Horse outside the
Appointment Barn, and duplicate Horse membership. SwiftData optionality and
`minimumModelCount` are not relied on as domain validation.

V3 applies the same representation rule to `Photograph.visitHorse`.
Photograph ownership remains domain-required and inverse-validated. Production
supports only Photograph creation and deletion; no update or reassignment path
exists after insertion.

### Photograph File Transactions

The canonical file is derived from Photograph UUID under
`Application Support/HoofPhotographs`; SwiftData stores no path. Temporary and
quarantine directories live beneath the same protected root so moves are
atomic on one volume.

Add writes and validates a normalized temporary JPEG, moves it to the
collision-safe canonical URL, then inserts and saves metadata. A failed save
rolls back the context and removes the canonical orphan. Delete first moves the
canonical file to quarantine, then deletes metadata; a failed save restores the
file. In-progress Visit discard applies the same quarantine pattern to every
owned photograph.

Launch and protected-data-availability reconciliation fetches all Photograph
metadata and safely inspects every managed directory before planning any
mutation. It restores a unique quarantine for existing metadata and purges only
strictly named managed temporary, quarantine, or canonical orphans. Ambiguous,
unknown, malformed, directory, and symbolic-link entries fail safe or remain
untouched. The filesystem state is the idempotent crash-recovery record; there
is no journal or background task.

Reads never force-unwrap stored relationships. If corrupted or externally
invalid persisted data is encountered, views render an unavailable value or
state and feature models surface an error instead of crashing. Controlled
application writes must never create such a graph.

Horse relocation is also a cross-record mutation rule. For every
`AppointmentHorse`, the Horses feature resolves the Appointment's Visit. An
Appointment with no Visit or an in-progress Visit blocks relocation regardless
of scheduled date. An Appointment with a completed Visit does not block it.
Missing or invalid relationships fail closed. Add Existing Horse uses the same
rule. Relocation never moves, deletes, or rewrites Appointment, Visit, or
snapshot data.

Complete-graph validation requires the Horse's current Barn to match the
Appointment Barn while no Visit exists or while its Visit is in progress. A
completed Visit permits later current-Barn divergence because the historical
location is preserved by immutable Visit snapshots.

## Feature Communication

Features communicate through:

- SwiftData persistent identifiers in routes.
- Immutable transient creation context, such as a preselected client or barn.
- Explicit completion values from sheets.
- SwiftData updates observed from the shared app container.

Features do not retain one another's feature models or use notifications as an
internal event bus. The database graph is authoritative; no Client–Barn shortcut
or duplicated derived ownership is persisted.

Appointment creation is Schedule-owned and reusable from Today. Horse editing
is Horses-owned and reusable from Clients and Barns. This reuse is initializer
and route based, not a global coordinator.

Visit start is Appointment-owned entry into a Visits-owned workflow. Visit
routes carry persistent identifiers. The Visit feature does not retain
Schedule or Horses feature models; the shared SwiftData graph remains
authoritative.

## Dates and Calendar Behavior

Persist appointment starts as absolute `Date` values. Present and group them
using the user's current calendar and time zone. Today queries use an injected
or explicitly supplied `Calendar` to calculate the local start and end of day,
which keeps daylight-saving and test behavior deterministic.

Schedule calculates the start of the current local calendar day using the same
calendar rule and fetches appointments at or after that boundary. It excludes
earlier appointments, groups results by local calendar day, orders groups
ascending, and orders appointments chronologically within each group. A
general past-Appointment destination remains deferred; completed Visit history
is available only from Horse Detail.

Expected duration remains optional. The absence of duration does not create or
imply an end date. The first slice does not derive duration from horse count,
service data, or historical work.

The horse appointment interval is stored as weeks and defaults to six. It is
domain data for later scheduling assistance; the first slice does not
automatically create a next appointment.

`Visit.startedAt` records the actual work start and is the primary Horse History
date. `Visit.completedAt` is nil while in progress and is captured once on
successful completion. Neither timestamp changes during correction.

Horse History includes completed Visits only and orders its projection by
`startedAt` descending, `completedAt` descending, immutable
service-location-name snapshot ascending, and Horse name ascending. No
persisted ordering identifier is introduced solely for display.

## Validation and Error Handling

Validation has three boundaries:

1. Editor validation prevents invalid drafts from being saved.
2. Domain rules enforce cross-record invariants such as barn eligibility,
   duplicate appointment horses, permitted relocation, and permitted deletion.
3. Persistence errors are surfaced to the feature model and presented with a
   native alert while keeping recoverable draft state.

Saving a graph is one user action. Insert related records, validate the complete
graph, save once, and report failure without displaying success-shaped state.
Required-record disappearance is shown as a native unavailable state.

Start Visit atomically creates the Visit, immutable Barn snapshots, and one
pending VisitHorse per AppointmentHorse. Save Progress and Complete Visit use
explicit feature-model drafts. Completion requires every outcome to be
resolved, at least one serviced Horse, exact Visit-to-Appointment membership,
and valid relationships.

Dirty Visit drafts are not persisted per keystroke. Backgrounding makes a
best-effort call to the same Save Progress boundary. A failure can be surfaced
on activation only if the same process resumes. Process termination loses the
unsaved draft and any in-memory error; relaunch restores the last successful
save.

## Testing Architecture

Tests use fixture builders scoped to the test target. Fixtures create valid
minimal records first and expose explicit customization for the scenario under
test. They do not weaken production validation.

The current test layers are:

- Unit tests for normalization, required fields, six-week interval behavior,
  duration validation, horse eligibility, duplicate selection, deletion
  preflight, relocation eligibility, and Today and Schedule calendar
  boundaries and ordering.
- In-memory SwiftData tests for relationships, inverses, ownership, and delete
  rules.
- Temporary on-disk store tests that create the complete graph, close every
  reference to the first container, reopen the same store, and fetch and verify
  the complete graph.
- UI smoke coverage for the connected creation flow and native navigation where
  reliable automation adds value.

Slice 2 adds:

- Unit tests for Visit state, outcomes, dirty drafts, completion, correction,
  Visit-aware relocation, Appointment locking, and exact Horse History
  ordering.
- In-memory SwiftData tests for the seven-model V2 graph, optional relationship
  storage, inverses, ownership, and delete rules.
- Real-store migration tests that create V1, release it, migrate the same store
  to V2, and verify that no Visit is fabricated.
- Reopening tests for pending, saved in-progress, completed, corrected,
  discarded, and post-completion-relocation graphs.
- UI acceptance coverage from Start Visit through Horse History and relaunch.

Slice 3 adds:

- V2-to-V3 and chained V1-to-V2-to-V3 migration coverage with no fabricated
  Photograph data.
- Image orientation, bounded resizing, sRGB conversion, metadata stripping,
  collision, file-protection, and backup-eligibility tests.
- Add, delete, rollback, missing-file, quarantine, orphan, protected-data, and
  idempotent reconciliation tests.
- Deterministic suspension-point tests proving exclusive serialization and the
  16-available-photograph limit under concurrent adds.
- Persistent reopening and camera/photo-picker entry coverage.

Production, preview, and test container creation use the same schema
registration so tests cannot accidentally validate a different model graph.

## Platform Policy

The product minimum is iOS 18.0 and the app is built with the latest stable iOS
26 SDK. Every app and test target declares the iOS 18.0 deployment minimum.

Core behavior uses APIs available on iOS 18. iOS 26-only APIs are optional
enhancements guarded by availability checks. The same navigation, persistence,
validation, and accessibility behavior must work on both platform generations.
Standard controls, rather than simulated platform effects, provide the
appropriate appearance on each OS.

## Explicit Non-Goals Through Slice 3

- Networking or server-backed repositories.
- CloudKit synchronization or backup.
- A dependency-injection framework or global service container.
- Third-party packages or a third-party design system.
- A generalized repository, global coordinator, or event bus.
- Unscheduled Visit horses, cancellation, no-show, or rescheduling state.
- Structured services, PDFs, invoices, payments, StoreKit, or
  notifications.
- Background tasks, external draft files, or per-change autosave.
- Completed Visit deletion or historical-date correction.
- Settings until concrete settings exist.
- Custom navigation, custom tabs, or custom iOS 26 visual effects.
