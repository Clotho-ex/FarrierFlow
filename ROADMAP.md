# FarrierFlow Roadmap

## Delivery Principle

FarrierFlow is delivered as complete vertical slices. Each slice must produce a
coherent user outcome, preserve the approved data contract, build successfully,
pass relevant tests, and work after relaunch before the next slice begins.

Later capabilities remain high-level until their product decisions, data
ownership, and migration behavior are shaped. They must not influence the first
schema or interface.

## Slice 0 — Foundation

### Outcome

Create the smallest reliable native foundation needed to implement and verify
the connected-record slice.

### Scope

- Align every app and test target with the approved iOS 18.0 minimum while
  building against the latest stable iOS 26 SDK.
- Confirm Swift 6 strict concurrency and iPhone-only configuration.
- Establish the approved feature-first source structure.
- Register the complete V1 SwiftData schema.
- Provide explicit production, preview, in-memory test, and temporary on-disk
  test container configurations.
- Establish `RootView` with native Today, Schedule, and Clients tabs and an
  independent `NavigationStack` per tab.
- Expose only Service Locations through the Clients toolbar menu.
- Create no Settings route, screen, folder, toolbar item, or empty destination.
- Add preview and test fixture infrastructure kept out of production startup.
- Add only the minimal semantic color, spacing, and typography tokens genuinely
  shared by first-slice screens.
- Establish localization storage and accessibility conventions for
  user-facing copy.

### Exit Criteria

- Production startup uses a durable SwiftData store and surfaces container
  creation failures.
- Preview and test configurations cannot write to the production store.
- The three native tabs preserve independent navigation state.
- The project builds for iOS 18 and iOS 26 simulator destinations available in
  the development environment.
- Foundation tests prove all V1 models are registered in every container
  configuration.

## Slice 1 — Connected Records

### Outcome

Complete the first useful workflow and prove the entire SwiftData graph survives
process termination and store reopening.

### Scope

#### Clients

- List, empty state, create, detail, edit, and permitted deletion.
- Required name with optional phone, email, and notes.
- Client detail offers Add Horse.
- Client deletion is blocked while any horse references it.

#### Independent Service Locations

- Service Locations entry in the Clients toolbar menu.
- List, empty state, create, detail, edit, and permitted deletion.
- Required name with optional address and contact notes.
- No persisted Client–Barn relationship.
- Service-location detail supports creating a horse for that location or adding
  an eligible existing horse.
- Add Existing Horse lists only horses with no appointment memberships that are
  not already assigned to the destination location.
- Deletion is blocked while a horse or appointment references the location.

#### Horses

- Create from client or service-location context.
- Required name, client, and current service location.
- Optional unstructured Safety Notes.
- Appointment interval defaults to six weeks and may be changed to another
  positive value.
- Horse creation can open a nested new-location sheet and return with the
  created location selected.
- Horse deletion is blocked while an appointment references it.
- Horse relocation is blocked while any appointment references it. The existing
  location remains unchanged and a native alert explains the rule.
- Relocation never moves, deletes, or rewrites an existing appointment.

#### Appointments

- Create from Today or Schedule.
- Required service location, start date and time, and at least one horse.
- Optional notes and optional positive expected duration in minutes.
- No expected-duration default and no derived end time.
- Eligible selection is limited to horses currently at the appointment's
  service location.
- Multiple horses, including horses owned by different clients, can share one
  barn appointment.
- Duplicate horses are prevented.
- Appointment deletion cascades only its join records.

#### Today and Schedule

- Today opens by default and shows appointments in the user's local current day.
- Schedule includes appointments from the start of the current local calendar
  day onward and excludes appointments before that boundary.
- Schedule groups appointments by local calendar day, orders date groups
  ascending, and orders appointments chronologically within each group.
- Past appointment and visit history are deferred.
- Appointment rows show start time, service location, and selected horses.
- When duration is absent, rows show no inferred end time.
- Empty states lead directly to appointment creation.

### Exact Acceptance Flow

The slice is accepted only after this sequence succeeds:

1. Create a client.
2. Create an independent service location.
3. Add a horse with that client and current service location.
4. Schedule a barn appointment containing that horse.
5. Show the appointment on Today.
6. Terminate and relaunch the app.
7. Verify the complete graph persisted: client, service location, horse,
   appointment, join, and every inverse relationship.

### Test and Quality Gates

- Unit tests cover normalization, required fields, interval validation,
  optional duration, horse eligibility, duplicate membership, deletion
  preflight, eligible existing-horse filtering, and local-day calculations.
- Relocation tests prove that any appointment membership blocks the change,
  preserves the horse's existing location, and leaves every Appointment and
  AppointmentHorse unchanged.
- Schedule tests cover the current local-day boundary, exclusion of earlier
  appointments, inclusion of today and future appointments, ascending day
  groups, and chronological ordering within each group.
- In-memory SwiftData tests cover relationships, inverses, ownership, and every
  delete rule.
- A temporary on-disk test creates the acceptance graph, releases the original
  container, reopens the same store, and verifies every record and relationship.
- Manual or automated UI verification covers contextual creation, nested
  service-location creation, blocked deletion and relocation alerts, empty
  states, and persistence after relaunch.
- VoiceOver, Dynamic Type, Light Mode, Dark Mode, Increased Contrast, and Reduce
  Motion checks cover the primary flow.
- The implementation is exercised on iOS 26 and receives an iOS 18
  compatibility pass.
- No deferred model, screen, dependency, or visual effect is introduced.

## Later Slices

The order below expresses product sequence, not an approved implementation
design. Each slice requires shaping before implementation.

### Slice 2 — Visit Completion

Record completed work against an appointment and establish horse history.

Before introducing completed visits or permanent horse history, re-evaluate
horse relocation and historical service-location semantics. Future records must
preserve where an appointment or visit occurred without permanently preventing
`Horse.currentBarn` from changing.

### Slice 3 — Hoof Photographs

Capture and manage hoof photographs with files stored in Application Support
and metadata stored in SwiftData.

### Slice 4 — Services and Pricing

Design the service catalog, work items, pricing rules, and horse default-service
behavior together. Money uses integer minor units and an explicit currency code,
never `Double`.

### Slice 5 — Invoicing

Create invoices from completed work and generate a professional shareable
document.

### Slice 6 — Payment Status

Track invoice payment status. Payment processing remains separate and requires
its own product decision.

### Slice 7 — Next Appointment

Use approved service presets or visit history to assist follow-up scheduling.
Do not infer first-slice duration or automatically schedule from the horse
interval without a later product decision.

### Slice 8 — Export

Define user-controlled business-record and media export with explicit privacy,
format, and failure behavior.

### Slice 9 — StoreKit Subscription

Introduce StoreKit 2 only after entitlement, pricing, restore, grace-period,
offline, and App Store requirements are approved.

### Slice 10 — Optional Backup

Evaluate an opt-in backup or synchronization design only after privacy,
conflict, account, recovery, migration, and operational requirements are
defined. CloudKit is not assumed.

## Deferred and Outside the First Slice

- Visits and work performed.
- Horse history beyond the connected first-slice graph.
- Hoof photographs and file storage.
- Service catalog, default service, pricing, and service presets.
- Invoices, PDFs, payment status, and payment processing.
- Automatic next-appointment creation.
- Export.
- StoreKit and subscriptions.
- Networking, accounts, integrations, CloudKit, synchronization, and backup.
- Notifications.
- Archive or generalized soft deletion.
- Custom navigation, custom tab bars, or custom iOS 26 visual effects.
- Settings until concrete settings exist.

The first slice must not add fields, routes, empty screens, services, or
abstractions for these deferred capabilities.
