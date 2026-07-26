# FarrierFlow Architecture

## Architectural Goals

FarrierFlow is a local-first, iPhone-only SwiftUI application. The first
vertical slice should prove native navigation, SwiftData relationships,
validation, deletion behavior, and durable persistence without adding
networking, CloudKit, third-party dependencies, or speculative infrastructure.

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

The first slice uses the approved feature-first structure:

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
│   └── DateAndTime/
│       └── CalendarRules.swift
├── Features/
│   ├── Today/
│   ├── Schedule/
│   ├── Clients/
│   ├── Barns/
│   └── Horses/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

This tree contains only active first-slice ownership. `Core/Utilities` may be
added only when a concrete first-slice utility is genuinely shared and has no
clearer domain owner. Later features such as visits, photographs, services,
invoices, payments, export, subscriptions, backup, and Settings receive their
own feature ownership only after each capability is shaped. No empty directory
or destination is created for them in Slice 0 or Slice 1.

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

`FarrierFlowApp` creates the production `ModelContainer` and supplies it through
SwiftUI's model-container environment. Slice 0 does not require an application
dependency container because no concrete app-level dependency exists beyond
the model container. A small composition value may be introduced later only
when a real app-level dependency requires it; it must not become a mutable
global singleton or service locator.

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
- Clients owns client list, client detail, and client creation.
- Horses owns horse list/detail/editor behavior reached from client or
  service-location context.
- Barns owns the Service Locations list, service-location detail, and
  service-location editor.
- The Clients toolbar menu exposes only Service Locations in the first slice.
  Service Locations is pushed within the Clients navigation stack.
- No Settings route, screen, folder, toolbar item, or empty destination exists
  in Slice 0 or Slice 1. Settings may be introduced later only when concrete
  settings require a destination.

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

Long-running work is not required in the first slice. Later background work
must define its own isolation and return immutable results to the main actor.

## Persistence Containers

`ModelContainerFactory` has explicit configurations:

- Production: a persistent on-disk store using the current versioned schema.
- Preview: an in-memory store populated only by preview-specific fixtures.
- Test: an in-memory store by default, with an explicit temporary on-disk
  configuration for store-reopening tests.

The app must fail visibly if the production container cannot be created. It
must not silently replace a failed durable store with an in-memory store.
Preview and test fixtures never enter production startup code.

The schema and migration plan live under `Core/Persistence`. A schema version is
a complete snapshot of the persisted models. Migration stages are introduced
only when a later approved slice changes persisted data.

## Domain and Persistence Boundaries

Views do not create fetch descriptors, insert models, save contexts, delete
records, or traverse persistence relationships to enforce business rules.
Feature models perform those operations directly through their `ModelContext`
or call a small domain use case when a rule is shared or independently
testable.

The first slice does not add a generalized repository layer. A focused
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

Editors and feature models require these selections, controlled creation paths
construct complete graphs, and complete-graph validation runs immediately
before every save. It rejects missing relationships, a Horse outside the
Appointment Barn, and duplicate Horse membership. SwiftData optionality and
`minimumModelCount` are not relied on as domain validation.

Reads never force-unwrap stored relationships. If corrupted or externally
invalid persisted data is encountered, views render an unavailable value or
state and feature models surface an error instead of crashing. Controlled
application writes must never create such a graph.

Horse relocation is also a cross-record mutation rule. Before changing
`Horse.currentBarn`, the Horses feature checks for any `AppointmentHorse`
membership. When one exists, it leaves `currentBarn` unchanged and returns a
blocked reason for a native alert. It never moves, deletes, or rewrites an
existing appointment. Add Existing Horse on service-location detail uses the
same rule and lists only horses with no appointment memberships whose current
barn differs from the destination.

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

## Dates and Calendar Behavior

Persist appointment starts as absolute `Date` values. Present and group them
using the user's current calendar and time zone. Today queries use an injected
or explicitly supplied `Calendar` to calculate the local start and end of day,
which keeps daylight-saving and test behavior deterministic.

Schedule calculates the start of the current local calendar day using the same
calendar rule and fetches appointments at or after that boundary. It excludes
earlier appointments, groups results by local calendar day, orders groups
ascending, and orders appointments chronologically within each group. Past
appointment and visit history are deferred.

Expected duration remains optional. The absence of duration does not create or
imply an end date. The first slice does not derive duration from horse count,
service data, or historical work.

The horse appointment interval is stored as weeks and defaults to six. It is
domain data for later scheduling assistance; the first slice does not
automatically create a next appointment.

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

## Testing Architecture

Tests use fixture builders scoped to the test target. Fixtures create valid
minimal records first and expose explicit customization for the scenario under
test. They do not weaken production validation.

The first-slice test layers are:

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

## Explicit Non-Goals for the First Slice

- Networking or server-backed repositories.
- CloudKit synchronization or backup.
- A dependency-injection framework or global service container.
- Third-party packages or a third-party design system.
- A generalized repository, coordinator, or event bus.
- Visits, photo storage, PDFs, invoices, payments, StoreKit, or notifications.
- Settings until concrete settings exist.
- Custom navigation, custom tabs, or custom iOS 26 visual effects.
