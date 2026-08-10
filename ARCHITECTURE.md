# FarrierFlow Architecture

## Architectural Goals

FarrierFlow is a local-first, iPhone-only SwiftUI application. Slices 1 through
5A provide connected records, Visit completion and Horse History,
VisitHorse-owned photographs, structured Services and WorkItems, immutable
Invoices, payment status, native PDF sharing, owner setup, and the Run Sheet
hub. Completed Slice 7 adds transient next-appointment assistance through the
existing Schedule and Visit boundaries. Release 1.0 adds StoreKit-owned access
control and native subscription presentation without changing the business
graph. The app adds no FarrierFlow networking, CloudKit, account, or third-party
dependency.

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

Source ownership through completed Slice 7 uses the approved feature-first
structure:

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
│   ├── Onboarding/
│   ├── Today/
│   ├── Schedule/
│   ├── Clients/
│   ├── Barns/
│   ├── Horses/
│   ├── Visits/
│   ├── Photographs/
│   ├── Services/
│   ├── BusinessProfile/
│   ├── Subscription/
│   ├── Export/
│   └── Invoices/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

This tree shows implemented ownership through Slice 5A and the committed Slice
7 assistant units.
`Features/Onboarding/` owns derived setup readiness and sequencing.
`Core/Utilities` contains
only utilities genuinely shared by active features with no clearer domain
owner. Next-appointment assistance remains Schedule-owned and reuses Visit and
Appointment routes rather than adding a feature directory. Export currently
contains only its approved version-1 format and CSV foundation on `main`; its
remaining implementation is paused for release. Subscription is an approved
release feature and owns only StoreKit entitlement and purchase presentation.
Later features such as backup and Settings receive ownership only after each
capability is active. No empty directory or destination is created for deferred
work.

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

`FarrierFlowApp` creates the production `ModelContainer`, one
`PhotographLibrary`, and one `SubscriptionAccessModel`, then supplies them
through SwiftUI's environment. The small composition value owns the concrete
Photograph file store and StoreKit entitlement source; it is neither a mutable
global singleton nor a service locator.

`RootView` owns first-run routing, the root `TabView`, and the selected tab.
When no valid BusinessProfile exists, it presents owner setup before exposing
the operational tabs. After the required identity step succeeds, it opens on
Today and contains three tabs:

1. Today
2. Schedule
3. Clients

Each tab owns a separate `NavigationStack` and path. Switching tabs therefore
does not discard navigation state or combine unrelated routes.

Owner setup is resumable from persisted truth and derives solely from the
single BusinessProfile. First run asks for its required name, then opens Today.
Service, Service Location, customer-record, contact, and owner-default setup
remain owned by their contextual features and never block identity completion.

`RootView` resolves subscription access and owner-setup readiness independently.
A verified entitlement with no BusinessProfile opens the existing owner setup.
No entitlement and no BusinessProfile opens the Subscription welcome surface.
No entitlement with an existing BusinessProfile opens the ordinary tabs in
read-only mode. A loading entitlement never exposes mutation controls.

## Route and Presentation Ownership

- Onboarding owns only first-run identity gating. It calls the existing
  BusinessProfile validation and persistence boundary; it does not retain
  Services or Barns feature models or duplicate their domain rules.
- Today owns the action-led Run Sheet hub, ranked next-action projection,
  chronological appointment workline, setup-readiness projection, and
  Today-specific routes. Its promoted Appointment or Visit summary replaces
  that record's immediate list row instead of duplicating it. Appointment
  creation remains owned by Schedule; invoice and owner-setup recovery continue
  through their owning features.
- Schedule owns appointment lists, appointment detail, appointment creation,
  appointment editing, next-appointment suggestion rules, current-graph
  projection, the transient assistant, and its immutable editor seed.
- Visits owns Visit start, in-progress editing, progress saving, completion,
  correction, detail presentation, and Visit-specific validation.
- Photographs owns camera and picker ingestion, normalization, file storage,
  VisitHorse collections, deletion, and reconciliation.
- Services owns the catalog, default prices, active availability, Horse default
  selection, and recorded WorkItem editing inside Visits.
- BusinessProfile owns the single reusable invoice identity and contact editor.
- Subscription owns stable StoreKit product identifiers, current-entitlement
  observation, the native subscription store, Restore Purchases, Manage
  Subscription, and the Today read-only notice. It owns no business record.
- Invoices owns Client-specific eligibility, atomic generation, immutable
  projections, list/detail state, payment status, deletion, native PDF rendering,
  temporary-file lifetime, and sharing.
- Clients owns client list, client detail, and client creation.
- Horses owns horse list/detail/editor behavior reached from client or
  service-location context.
- Barns owns the Service Locations list, service-location detail, and
  service-location editor.
- The Clients toolbar menu exposes Service Locations, Services, Invoices, My
  Business, and the concrete Subscription destination. Each destination remains
  inside the Clients navigation stack.
- No generalized Settings route, screen, folder, toolbar item, or empty
  destination exists through Slice 7. Business Profile remains the
  concrete owner-configuration destination. Settings may be introduced later
  only when concrete settings require a destination. Subscription does not
  create a generalized Settings screen.

Appointment Detail owns the entry into Visits: Start Visit when none exists,
Resume Visit while in progress, and View Visit after completion. Today may
resume the same Visit editor directly; completion dismisses back to Today so
the projection can surface eligible invoice work. Visit Detail is shared by
Appointment Detail and Horse History and exposes the recoverable Schedule-owned
next-appointment assistant. The Unit 5 handoff passes only a
successfully completed Visit identifier and waits for the Visit editor to
dismiss before Today or Appointment Detail presents that assistant. Horse
Detail owns its completed-history projection and routes to Visit Detail. No
Visit tab or global history destination is added.

Client Detail owns Create Invoice. Successful generation replaces the creation
route with Invoice Detail. Invoice list and Business Profile are also reachable
from Clients > More; no Invoice tab or custom document browser is added.

The presenting feature owns sheet presentation state and any transient context,
such as a preselected client. The presented editor owns its draft, validation,
Save, and Cancel behavior. A nested service-location sheet returns the newly
created location to the horse editor without creating a persisted Client–Barn
relationship. When no Client exists, the horse editor may present Client
creation and select the saved Client without discarding its existing draft.

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

`SubscriptionAccessModel` is also `@MainActor @Observable`. A focused Sendable
entitlement source iterates verified `Transaction.currentEntitlements` and
listens for relevant `Transaction.updates`. The model publishes only loading,
full-access, or read-only state. It does not expose StoreKit transactions to
business features or persist a parallel entitlement Boolean.

Existing feature views read access state at their mutation-entry boundary.
They continue passing ordinary actions to their existing feature models only
while full access is current. Existing feature models, domain rules, and
SwiftData models do not import StoreKit. An already-open Visit editor also
checks access before explicit or background persistence.

The Today hub model fetches and converts cross-feature records into immutable
summary values before rendering. SwiftUI views never traverse the complete
SwiftData graph to rank actions. Ranking is deterministic: an in-progress Visit
comes before the next scheduled Appointment, first-Client activation,
uninvoiced completed work, unpaid Invoice attention, and general appointment
creation. Missing Services and Service Locations recover inside Visit work
recording and Appointment creation instead of competing for attention on Today.
When two candidates have equal rank, stable date and persistent-identity
ordering resolves the tie.

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

The first shipping store uses `FarrierFlowSchemaV1`, which registers the complete
14-model graph through Slice 5A. Slice 5A adds only optional
owner-default scalars to BusinessProfile and no new model. FarrierFlow has not
shipped, so pre-release V1-to-V4 stores receive no migration path. Future
shipping schema changes must preserve the production store identity and require
an explicitly designed and tested migration.

Subscription access is not persisted in SwiftData. Entitlement loss, restore,
renewal, grace, expiration, or revocation cannot add, delete, hide, repair, or
rewrite any business record or Photograph file. Read-only screens use the same
container and canonical files as full-access screens.

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

The shipping schema applies the same storage rule to `Visit.appointment`, `Visit.barn`,
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

It applies the same representation rule to `Photograph.visitHorse`.
Photograph ownership remains domain-required and inverse-validated. Production
supports only Photograph creation and deletion; no update or reassignment path
exists after insertion.

The shipping schema applies the same optional-storage/domain-required rule to
Service, WorkItem, BusinessProfile, Invoice, InvoiceVisit, and InvoiceLineItem
relationships. `Invoice.client`, `InvoiceVisit.invoice/sourceVisit`, and
`InvoiceLineItem.invoiceVisit/sourceWorkItem` are required by domain validation.
Each WorkItem may have at most one inverse InvoiceLineItem, while one source
Visit may appear in separate InvoiceVisits for different Clients.

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

### Invoice Transactions and PDF Boundary

Invoice eligibility derives Client-owned WorkItems from completed Visits. A
selected Visit contributes all and only that Client's uninvoiced WorkItems; the
same mixed-client Visit may therefore be snapshotted in different Invoices.
Generation uses an isolated action context and one validated save for the next
number, Invoice, InvoiceVisits, InvoiceLineItems, and WorkItem billing inverses.
A failed save rolls back the complete graph and does not consume the number.

Generated financial content is immutable. Detail projection and PDF content use
only Invoice snapshot models. The native renderer creates US Letter pages on
demand, and a feature model owns the temporary file until the system share sheet
finishes. Cleanup is best-effort and idempotent; PDF failure never saves or
mutates the Invoice.

Mark Paid records status and payment date atomically. Unpaid deletion removes
only invoice snapshots and their WorkItem billing links. Visit correction is
available again only when no remaining InvoiceLineItem references any WorkItem
from that Visit; a Paid reference remains permanent.

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

Invoice generation similarly validates Business Profile, Client-specific
eligibility, one-time WorkItem billing, sequence monotonicity, snapshot
normalization, currency consistency, and checked integer totals before one save.
Status change and unpaid deletion use focused atomic use cases. Every failure
surfaces human error copy without success-shaped navigation or partial state.

Dirty Visit drafts are not persisted per keystroke. Backgrounding makes a
best-effort call to the same Save Progress boundary. A failure can be surfaced
on activation only if the same process resumes. Process termination loses the
unsaved draft and any in-memory error; relaunch restores the last successful
save.

New Appointment drafts may read `defaultAppointmentDurationMinutes` from the
BusinessProfile once during draft creation. New Invoice drafts may read
`defaultInvoiceDueDays` and `defaultInvoiceNote` once. Later profile edits never
rewrite an open draft, existing Appointment, generated Invoice, or snapshot.
Every prefilled value remains visible and editable before save.

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

Visit coverage includes:

- Unit tests for Visit state, outcomes, dirty drafts, completion, correction,
  Visit-aware relocation, Appointment locking, and exact Horse History
  ordering.
- In-memory SwiftData tests for the Visit graph, optional relationship
  storage, inverses, ownership, and delete rules.
- Reopening tests for pending, saved in-progress, completed, corrected,
  discarded, and post-completion-relocation graphs.
- UI acceptance coverage from Start Visit through Horse History and relaunch.

Photograph coverage includes:

- Image orientation, bounded resizing, sRGB conversion, metadata stripping,
  collision, file-protection, and backup-eligibility tests.
- Add, delete, rollback, missing-file, quarantine, orphan, protected-data, and
  idempotent reconciliation tests.
- Deterministic suspension-point tests proving exclusive serialization and the
  16-available-photograph limit under concurrent adds.
- Persistent reopening and camera/photo-picker entry coverage.

Service and Invoice coverage includes catalog and WorkItem rules, mixed-client
eligibility, duplicate billing rejection, checked totals, sequence rollback,
immutable snapshots, status/deletion locking, persistent reopening, PDF content
and pagination, temporary-file lifetime, native sharing, and the full UI flow
from Client Detail through Paid history after relaunch.

Production, preview, and test container creation use the same schema
registration so tests cannot accidentally validate a different model graph.

Slice 5A coverage adds single-field owner-setup persistence, existing-user bypass, default
application and override behavior, deterministic Today action ranking,
scheduled and active-Visit Run Sheet projections, promoted-record
deduplication, accessibility progress semantics, and persistent reopening of
the revised BusinessProfile fields.

Release 1.0 subscription coverage adds verified-entitlement projection,
transaction-update transitions, no-profile first launch, existing-data
read-only launch, mutation-control gating, editor entitlement loss, invoice PDF
availability, Restore/Manage presentation, and deterministic full-access UI
test injection. StoreKit Configuration testing covers trial, renewal, grace,
billing retry, expiration, restore, and revocation without a production server.

## Platform Policy

The product minimum is iOS 18.0 and the app is built with the latest stable iOS
26 SDK. Every app and test target declares the iOS 18.0 deployment minimum.

Core behavior uses APIs available on iOS 18. iOS 26-only APIs are optional
enhancements guarded by availability checks. The same navigation, persistence,
validation, and accessibility behavior must work on both platform generations.
Standard controls, rather than simulated platform effects, provide the
appropriate appearance on each OS.

## Explicit Non-Goals for Release 1.0

- Networking or server-backed repositories.
- CloudKit synchronization or backup.
- A dependency-injection framework or global service container.
- Third-party packages or a third-party design system.
- A generalized repository, global coordinator, or event bus.
- Unscheduled Visit horses, cancellation, no-show, or rescheduling state.
- Taxes, discounts, partial payments, payment processing, overdue automation,
  recurring billing, statements, custom numbering, invoice theming, accounting
  integrations, or notifications.
- Subscription accounts, server receipt validation, persisted entitlement
  state, weekly or lifetime products, writable free limits, team plans, and
  third-party billing.
- Completion of the remaining Slice 8 Export units before revenue launch.
- Background tasks, external draft files, or per-change autosave.
- Completed Visit deletion or historical-date correction.
- A generalized Settings destination beyond the concrete Business Profile and
  approved owner defaults.
- Custom navigation, custom tabs, or custom iOS 26 visual effects.
