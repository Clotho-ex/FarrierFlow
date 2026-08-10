# FarrierFlow Data Model

## Scope

This document defines the implemented first-shipping SwiftData contract through
Slice 5A. The graph supports independent
clients and service locations, horses owned by
clients and currently located at one service location, barn-centric
appointments containing one or more horses, Visit records that preserve
performed-work outcomes and Horse History, Photograph metadata owned by
individual VisitHorse records, structured Services and WorkItems, and immutable
Client Invoices. The BusinessProfile also owns optional reusable
Appointment-duration and Invoice-due defaults introduced by Slice 5A.

This contract remains current through Slice 7. Next-appointment assistance is a
transient projection over the existing Visit, Horse, Appointment, and
AppointmentHorse graph; only the ordinary Appointment save boundary persists a
reviewed result. Slice 7 adds no model, field, relationship, schema version, or
migration stage.

SwiftData is the local metadata source of truth. Canonical Photograph JPEGs are
stored in Application Support and resolved only from their UUID. Invoice PDFs
are generated on demand from persisted snapshots and are not canonical records.
No model represents payment processing, subscriptions, cloud synchronization,
or app-managed backup. Release 1.0 entitlement is verified from StoreKit at
runtime and adds no SwiftData model, field, relationship, schema version, or
migration. An access-state transition never mutates this graph.

## Relationship Contract

- A client can own multiple horses.
- A client can have horses at multiple service locations.
- A service location can contain horses owned by multiple clients.
- A horse belongs to exactly one client.
- A horse has exactly one current service location.
- A service location is not attached directly to a client.
- An appointment belongs to exactly one service location.
- An appointment contains one or more horses through `AppointmentHorse`.
- Every selected horse must currently belong to the appointment's service
  location.
- Client information for an appointment is derived from its selected horses.
- One appointment may contain horses owned by multiple clients.
- An appointment has zero or one Visit.
- A Visit belongs to exactly one Appointment and one Barn.
- A Visit contains exactly one VisitHorse for every AppointmentHorse.
- A VisitHorse belongs to exactly one Visit and one Horse.
- A Photograph belongs to exactly one VisitHorse and never changes ownership.
- A VisitHorse may own photographs while Pending, Serviced, or Not Serviced.
- An active Service may be recorded once per VisitHorse as a WorkItem; each
  WorkItem snapshots Service name, USD amount in minor units, and currency.
- One Invoice belongs to exactly one Client and contains one or more
  InvoiceVisits and InvoiceLineItems.
- A mixed-client Visit may appear in separate Invoices for different Clients.
- Each source WorkItem may belong to at most one InvoiceLineItem.
- InvoiceVisit groups one source Visit inside one Invoice and does not own the
  entire source Visit globally.
- Visit history displays immutable service-location name and optional address
  snapshots captured when Start Visit succeeds.

“Barn” is the persisted domain name for any service location, including a
commercial barn, private stable, or client residence. User-facing copy may use
“Service Location” where that is clearer.

Required to-one relationships use nullable SwiftData storage where deletion
needs to clear an inverse safely on iOS 18. This is a persistence
representation detail only. It does not make those relationships optional to
the user or to the product domain. Controlled creation and mutation paths must
provide every required relationship and validate the complete graph before
saving.

## Schema Versions and Migration

`FarrierFlowSchemaV1` is the first shipping schema and registers all 14 current
models. FarrierFlow has not shipped, so pre-release V1-to-V4 stores are not a
supported migration source and no migration plan is implemented for them.
SwiftData supplies model identity. Any schema change after first shipment
requires an explicit version and migration design before implementation.

## Client

### Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `name` | `String` | Required |
| `phone` | `String?` | Optional |
| `email` | `String?` | Optional |
| `notes` | `String?` | Optional |

### Relationships

- `horses: [Horse]` is the inverse of `Horse.client`.
- `invoices: [Invoice]` is the deny-rule inverse of `Invoice.client`.
- The relationship does not cascade. It records ownership of each horse but
  does not give Client ownership of the horse's persistence lifetime.
- There is no direct relationship to `Barn`.

### Validation

- `name`, after trimming surrounding whitespace and newlines, must not be
  empty.
- Optional text fields store `nil` when their normalized value is empty.
- Email and phone are optional. The first slice does not reject otherwise
  saveable records based on regional formatting rules.

### Deletion

A client may be deleted only when `horses` and `invoices` are empty. When either
relationship references the client, the feature model prevents deletion and presents a native alert
explaining which records must be retained or removed first. Neither Horses nor
Invoices cascade from a client deletion.

## Barn

### Meaning

`Barn` represents an independent service location. It may be a commercial barn,
private stable, or client residence.

### Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `name` | `String` | Required |
| `address` | `String?` | Optional |
| `contactNotes` | `String?` | Optional |

### Relationships

- `horses: [Horse]` is the inverse of `Horse.currentBarn`.
- `appointments: [Appointment]` is the inverse of `Appointment.barn`.
- `visits: [Visit]` is the inverse of `Visit.barn`.
- There is no direct relationship to `Client`.
- No Barn relationship cascades.

### Validation

- `name`, after trimming surrounding whitespace and newlines, must not be
  empty.
- Optional text fields store `nil` when their normalized value is empty.
- An address is not required to create a service location. Navigation or
  mapping actions remain unavailable until an address exists.

### Deletion

A barn may be deleted only when `horses`, `appointments`, and `visits` are all
empty. If any relationship exists, the feature model prevents deletion and
presents a native alert naming the records that must be reassigned, removed, or
retained. Barn deletion never cascades to horses, appointments, or visits.

## Horse

### Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `name` | `String` | Required |
| `safetyNotes` | `String?` | Optional |
| `appointmentIntervalWeeks` | `Int` | Required, defaults to `6` |

### Relationships

- `client: Client?` is the inverse of `Client.horses`. Optional in SwiftData
  storage for deletion compatibility; required by the domain contract and
  validated before save.
- `currentBarn: Barn?` is the inverse of `Barn.horses`. Optional in SwiftData
  storage for deletion compatibility; required by the domain contract and
  validated before save.
- `appointmentHorses: [AppointmentHorse]` is the inverse of
  `AppointmentHorse.horse`.
- `visitHorses: [VisitHorse]` is the inverse of `VisitHorse.horse`.
- `defaultService: Service?` is optional and must reference an active Service
  when present.
- No relationship cascades from Horse.

### Validation

- `name`, after trimming surrounding whitespace and newlines, must not be
  empty.
- `client` and `currentBarn` must resolve to persisted records in the editing
  context.
- `safetyNotes` stores `nil` when its normalized value is empty. It is
  unstructured Safety Notes text; V1 defines no warning taxonomy or collection.
- `appointmentIntervalWeeks` must be greater than zero and begins at six unless
  the user chooses another positive value.

### Relocation

`currentBarn` may change only when every AppointmentHorse membership resolves
to an Appointment with a completed Visit.

- Appointment with no Visit: blocks relocation.
- Appointment with an in-progress Visit: blocks relocation.
- Appointment with a completed Visit: does not block relocation.
- Missing or invalid relationships: fail closed and block relocation.

Scheduled time does not infer completion. A past Appointment without a
completed Visit still blocks relocation.

Add Existing Horse applies the same rule and excludes horses already assigned
to the destination. As a defensive invariant, an independently encountered
in-progress VisitHorse also blocks relocation.

Relocation never moves, deletes, retargets, or otherwise rewrites Appointment,
AppointmentHorse, Visit, VisitHorse, or snapshot data.

### Deletion

A horse may be deleted only when `appointmentHorses` and `visitHorses` are
empty. If an Appointment or Visit references it, the feature model prevents
deletion. Deleting a horse never deletes its client, barn, appointment, visit,
or join records.

Archiving and historical retention are intentionally not represented in this
schema.

## Appointment

### Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `startDate` | `Date` | Required |
| `notes` | `String?` | Optional |
| `expectedDurationMinutes` | `Int?` | Optional, no default |

### Relationships

- `barn: Barn?` is the inverse of `Barn.appointments`. Optional in SwiftData
  storage for deletion compatibility; required by the domain contract and
  validated before save.
- `appointmentHorses: [AppointmentHorse]` is required to contain at least one
  join and is the inverse of `AppointmentHorse.appointment`.
- `visit: Visit?` is the inverse of `Visit.appointment` and expresses zero or
  one Visit.
- Appointment owns the persistence lifetime of its join records.
- Appointment does not own Barn, Horse, Client, or Visit.

### Validation

- `barn` must resolve to a persisted record in the editing context.
- `startDate` is an absolute date and time. There is no required end date.
- `notes` stores `nil` when its normalized value is empty.
- `expectedDurationMinutes` is either `nil` or greater than zero.
- The appointment must contain at least one `AppointmentHorse`.
- Every joined horse's `currentBarn` must equal the appointment's `barn`.
- The same horse may appear no more than once in an appointment.
- Once a Visit exists, Barn and AppointmentHorse membership are immutable.
- Scheduled start, notes, and expected duration remain editable only when their
  mutation leaves the Visit graph unchanged and valid.

Expected duration is not derived from horse count. A new Appointment draft may
prefill it from the current BusinessProfile's optional owner default. The value
remains editable and is copied into the Appointment only when that draft is
saved. Existing Appointments never change when the owner default changes. When
duration is absent, Today and Schedule display only the start time.

### Deletion

An Appointment with a Visit cannot be deleted. When no Visit exists, deleting
an Appointment cascades only to its AppointmentHorse records. It never deletes
its Barn, Horses, Clients, or Visit.

## AppointmentHorse

### Fields

AppointmentHorse has no scalar application fields in V1 or V2.

### Relationships

- `appointment: Appointment?` is the inverse of
  `Appointment.appointmentHorses`. Optional in SwiftData storage for deletion
  compatibility; required by the domain contract and validated before save.
- `horse: Horse?` is the inverse of `Horse.appointmentHorses`. Optional in
  SwiftData storage for deletion compatibility; required by the domain contract
  and validated before save.
- The join is owned by Appointment.

### Invariants

- The pair `(appointment, horse)` is unique within the appointment.
- `horse.currentBarn` equals `appointment.barn` when the graph is saved.
- Removing a join removes only appointment membership.
- Removing a join never deletes the horse.
- Once the Appointment has a Visit, membership cannot be added, removed, or
  replaced.

SwiftData relationship metadata does not replace the uniqueness check. The
appointment feature model prevents duplicate selection before inserting a join
and validates the complete set again before saving.

## Visit

### Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `startedAt` | `Date` | Required and immutable |
| `completedAt` | `Date?` | Nil in progress; set once on completion |
| `serviceLocationNameSnapshot` | `String` | Required, normalized, immutable |
| `serviceLocationAddressSnapshot` | `String?` | Optional, normalized, immutable |

Visit state is derived from `completedAt`; it is not redundantly persisted.

- `completedAt == nil` means in progress.
- `completedAt != nil` means completed.
- `completedAt` must not be earlier than `startedAt`.
- Normal editing and completed correction never change either timestamp.

### Relationships

- `appointment: Appointment?` is the inverse of `Appointment.visit`. Optional
  in SwiftData storage for iOS 18 deletion compatibility; required by the
  domain contract and validated before save.
- `barn: Barn?` is the inverse of `Barn.visits`. Optional in SwiftData storage
  for iOS 18 deletion compatibility; required by the domain contract and
  validated before save.
- `visitHorses: [VisitHorse]` is the inverse of `VisitHorse.visit`, contains at
  least one valid membership, and uses cascade because Visit owns the joins.
- `invoiceVisits: [InvoiceVisit]` is the deny-rule inverse of
  `InvoiceVisit.sourceVisit`. It may contain entries from multiple Client
  Invoices for one mixed-client Visit.

The Barn reference preserves service-location identity and supports navigation
when the record resolves. Visit Detail and Horse History always display the
immutable name and address snapshots captured from the Appointment Barn when
Start Visit succeeds. Missing Barn storage never makes those snapshots
unreadable.

### Creation and validation

Start Visit requires:

- An Appointment with no Visit.
- A valid Appointment Barn with a nonempty normalized name.
- At least one valid, unique AppointmentHorse.
- Every Horse at the Appointment Barn with valid Client and current Barn
  relationships.

One save creates the Visit and exactly one pending VisitHorse for every
AppointmentHorse. No partial graph may remain if validation or saving fails.

Save Progress permits pending outcomes and requires `completedAt == nil`.
Completion requires every outcome to be resolved, at least one serviced Horse,
exact VisitHorse-to-AppointmentHorse Horse equality, and all required
relationships. Completion saves the current draft and `completedAt` atomically.

### Correction and deletion

Completed correction may change serviced/not-serviced outcomes, Work Notes, and
recorded WorkItems while no WorkItem in the Visit is invoiced. It preserves
relationships, membership, timestamps, snapshots, and completed state and must
continue satisfying every completion invariant. Once any WorkItem is invoiced,
correction is locked; other uninvoiced Client portions may still be invoiced.

An in-progress Visit may be discarded with confirmation, cascading only its
VisitHorse records. A completed Visit cannot be deleted.

## VisitHorse

### Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `outcomeRawValue` | `String` | Required; defaults to `pending` |
| `workNotes` | `String?` | Optional only when serviced |

The domain outcome is exactly one of:

- `pending`
- `serviced`
- `notServiced`

Unknown raw values are invalid and are never displayed directly. Work Notes
store `nil` after normalization when empty and must be nil for pending or
not-serviced outcomes.

### Relationships

- `visit: Visit?` is the inverse of `Visit.visitHorses`. Optional in SwiftData
  storage for iOS 18 deletion compatibility; required by the domain contract.
- `horse: Horse?` is the inverse of `Horse.visitHorses`. Optional in SwiftData
  storage for iOS 18 deletion compatibility; required by the domain contract.
- `photographs: [Photograph]` is the inverse of `Photograph.visitHorse`.
  VisitHorse owns Photograph persistence lifetime through a cascade rule.
- `workItems: [WorkItem]` is the inverse of `WorkItem.visitHorse` and cascades
  with VisitHorse ownership.

VisitHorse does not reference AppointmentHorse directly. The pair
`(visit, horse)` is unique, and the VisitHorse Horse set must exactly equal the
owning Appointment's AppointmentHorse Horse set.

VisitHorse membership is owned by Visit. It cannot be individually added,
removed, or deleted after Start Visit. Deleting an owned VisitHorse never
deletes its Horse.

## Photograph

### Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `id` | `UUID` | Required and unique |
| `createdAt` | `Date` | Required |
| `pixelWidth` | `Int` | Required and positive |
| `pixelHeight` | `Int` | Required and positive |
| `byteCount` | `Int64` | Required and positive |

The maximum dimension is 2,560 pixels. The UUID, creation date, dimensions,
byte count, and owner are assigned only during creation. The shipping product supports no
metadata edit, owner reassignment, identifier mutation, or in-place file
replacement.

### Relationships and file identity

- `visitHorse: VisitHorse?` is optional only as an iOS 18 deletion-safe
  SwiftData representation and is required by the domain.
- The canonical file URL is derived exclusively from `id` as
  `Application Support/HoofPhotographs/<lowercase-uuid>.jpg`.
- No path, source kind, original filename, asset identifier, caption,
  classification, EXIF data, or thumbnail metadata is persisted.
- Deleting a Photograph deletes only that record and its canonical file.
- Deleting an in-progress Visit removes its Photograph records and files through
  the photo-aware discard transaction.

## Service and WorkItem

`Service` stores a required normalized name, nonnegative default amount in USD
minor units, currency code, and archive state. An archived Service remains
historical but is not eligible for new WorkItems or as a Horse default.

`WorkItem` belongs to one VisitHorse and one Service. It stores the recorded
Service-name, amount, and currency snapshots. A VisitHorse prevents
duplicate WorkItems for the same Service. Every serviced VisitHorse must have at
least one WorkItem before completion; not-serviced VisitHorses have none. A
completed Visit may correct these values only until any of its WorkItems is
invoiced.

`WorkItem.invoiceLineItem` is optional until billed and is the one-to-one inverse
that prevents duplicate billing. Editing completed Visit work is locked whenever
any WorkItem from that Visit has an InvoiceLineItem reference.

## BusinessProfile

Exactly zero or one BusinessProfile may exist. It requires a normalized business
or farrier name.

| Field | Type | Requirement |
| --- | --- | --- |
| `name` | `String` | Required, normalized nonempty text |
| `phone` | `String?` | Optional normalized text |
| `email` | `String?` | Optional normalized text |
| `address` | `String?` | Optional normalized text |
| `defaultAppointmentDurationMinutes` | `Int?` | Optional; positive when present |
| `defaultInvoiceDueDays` | `Int?` | Optional; positive when present; begins at 14 |
| `defaultInvoiceNote` | `String?` | Optional normalized text |
| `nextInvoiceNumber` | `Int64` | Required positive sequence value; begins at 1 |

`nil` duration means Ask Every Time. `nil` due days means No Due Date. These are
owner preferences for new transient drafts, not persisted links to Appointments
or Invoices. A new Appointment draft copies the duration default once. A new
Invoice draft derives its due date by adding the due-day default to its Invoice
Date and copies the note once. Clearing or editing either draft never edits the
BusinessProfile.

`nextInvoiceNumber` is never user-editable, advances only with a successful
Invoice save, and must remain greater than every issued number.

## Invoice

An Invoice belongs to exactly one Client and stores immutable Client and Business
Profile name/contact snapshots, number, invoice date, optional due date, optional
note, currency, status, and optional payment date. Numbers are positive,
formatted to at least four digits, sequential, and never reused. Status is Unpaid
or Paid; Paid requires a payment date and cannot be reversed or deleted.

An Invoice owns one or more InvoiceVisits by cascade. Its checked total is
derived from all InvoiceLineItem minor-unit amounts and is never stored as a
separate mutable value.

## InvoiceVisit

InvoiceVisit belongs to one Invoice, references one source Visit, and snapshots
Visit date plus Service Location name and optional address. The source Visit
relationship is not globally unique: the same mixed-client Visit may appear in
different Client Invoices. InvoiceVisit owns one or more InvoiceLineItems by
cascade.

## InvoiceLineItem

InvoiceLineItem belongs to one InvoiceVisit, references exactly one source
WorkItem, and snapshots Horse name, Service name, amount, and currency. Its
source WorkItem relationship is globally one-to-one and is the duplicate-billing
boundary. Every line in one Invoice must belong to the Invoice Client through
the source WorkItem's VisitHorse and Horse at generation time.

Deleting an Unpaid Invoice cascades only its InvoiceVisits and InvoiceLineItems;
the one-to-one inverse releases each WorkItem. Client, Visit, VisitHorse, Horse,
Service, WorkItem, and Photograph records remain. A Visit becomes correctable
again only if no remaining InvoiceLineItem references any of its WorkItems.

## Ownership and Delete-Rule Matrix

| Source relationship | Inverse | SwiftData delete rule | Result when source is deleted |
| --- | --- | --- | --- |
| `Client.horses` | `Horse.client` | Deny | Client cannot be deleted while the collection is nonempty |
| `Horse.client` | `Client.horses` | Nullify | Deleting an eligible horse removes it from the client's inverse collection; Client remains |
| `Barn.horses` | `Horse.currentBarn` | Deny | Barn cannot be deleted while the collection is nonempty |
| `Horse.currentBarn` | `Barn.horses` | Nullify | Deleting an eligible horse removes it from the barn's inverse collection; Barn remains |
| `Barn.appointments` | `Appointment.barn` | Deny | Barn cannot be deleted while the collection is nonempty |
| `Appointment.barn` | `Barn.appointments` | Nullify | Deleting an appointment removes it from the barn's inverse collection; Barn remains |
| `Horse.appointmentHorses` | `AppointmentHorse.horse` | Deny | Horse cannot be deleted while the collection is nonempty |
| `AppointmentHorse.horse` | `Horse.appointmentHorses` | Nullify | Deleting a join removes it from the horse's inverse collection; Horse remains |
| `Appointment.appointmentHorses` | `AppointmentHorse.appointment` | Cascade | Deleting an appointment deletes its joins |
| `AppointmentHorse.appointment` | `Appointment.appointmentHorses` | Nullify | Deleting a join removes it from the appointment's inverse collection; Appointment remains |
| `Appointment.visit` | `Visit.appointment` | Deny | Appointment cannot be deleted while a Visit exists |
| `Visit.appointment` | `Appointment.visit` | Nullify | Discarding an allowed Visit clears the Appointment inverse; Appointment remains |
| `Barn.visits` | `Visit.barn` | Deny | Barn cannot be deleted while any Visit references it |
| `Visit.barn` | `Barn.visits` | Nullify | Deleting an allowed Visit removes it from the Barn inverse; Barn remains |
| `Horse.visitHorses` | `VisitHorse.horse` | Deny | Horse cannot be deleted while Visit history references it |
| `VisitHorse.horse` | `Horse.visitHorses` | Nullify | Deleting an owned join removes only the inverse; Horse remains |
| `Visit.visitHorses` | `VisitHorse.visit` | Cascade | Discarding an in-progress Visit deletes its joins |
| `VisitHorse.visit` | `Visit.visitHorses` | Nullify | Deleting an owned join never deletes its Visit |
| `VisitHorse.photographs` | `Photograph.visitHorse` | Cascade | Deleting an owned VisitHorse deletes its Photograph metadata after its files are quarantined |
| `Photograph.visitHorse` | `VisitHorse.photographs` | Nullify | Deleting a Photograph removes only the inverse; VisitHorse remains |
| `Client.invoices` | `Invoice.client` | Deny | Client cannot be deleted while Invoice history references it |
| `Invoice.client` | `Client.invoices` | Nullify | Deleting an eligible unpaid Invoice removes only the inverse; Client remains |
| `Service.workItems` | `WorkItem.service` | Deny | Service cannot be deleted while historical WorkItems reference it |
| `VisitHorse.workItems` | `WorkItem.visitHorse` | Cascade | Deleting an owned in-progress VisitHorse deletes its WorkItems |
| `WorkItem.invoiceLineItem` | `InvoiceLineItem.sourceWorkItem` | Deny | A billed WorkItem cannot be deleted or billed again |
| `Visit.invoiceVisits` | `InvoiceVisit.sourceVisit` | Deny | A Visit with invoice history cannot be deleted |
| `Invoice.invoiceVisits` | `InvoiceVisit.invoice` | Cascade | Deleting an Unpaid Invoice deletes its Visit snapshots |
| `InvoiceVisit.lineItems` | `InvoiceLineItem.invoiceVisit` | Cascade | Deleting an owned InvoiceVisit deletes its line snapshots and releases WorkItem inverses |

Feature-model preflight checks are required even where the SwiftData delete rule
also denies deletion. The preflight provides a clear user explanation; the
schema rule protects the graph if a call site bypasses that interface.
The Nullify entries for required domain relationships are enabled by optional
SwiftData storage. They support safe inverse cleanup during deletion; they do
not permit controlled application writes to omit a relationship.

## Validation Boundaries

### Editor Boundary

Editors normalize strings, require mandatory selections, validate positive
numeric values, and disable Save until their draft is locally valid.

The Visit editor owns an in-memory draft separate from the last saved
VisitHorse state. It tracks dirty state, preserves the draft on save failure,
and requires confirmation before dismissing unsaved changes. Save Progress and
Complete Visit are explicit persistence actions.

### Domain Boundary

Domain rules validate relationships that span models:

- Appointment has at least one horse.
- Appointment horses are unique.
- Appointment horses currently belong to the selected barn.
- Horse relocation is allowed only when every Appointment membership has a
  completed Visit and no in-progress VisitHorse is encountered.
- An Add Existing Horse candidate passes the same Visit-aware relocation rule
  and is not already assigned to the destination barn.
- Delete preconditions are satisfied.
- Visit has exactly one Appointment and Barn.
- VisitHorse membership exactly matches AppointmentHorse membership.
- Visit timestamps and immutable snapshots are valid.
- Visit outcome and Work Notes match the current Visit state.
- Completed correction preserves relationships, timestamps, snapshots, and
  completed state.
- Photograph has one current inverse-matching VisitHorse owner.
- Photograph dimensions and byte count are positive, the longest edge is at
  most 2,560 pixels, and Photograph UUIDs are unique.
- Service names and USD amounts are valid; archived Services are not used for
  new defaults or WorkItems.
- Serviced VisitHorses have recorded WorkItems, with no duplicate Service;
  not-serviced VisitHorses have none.
- Business Profile count is at most one and its sequence remains ahead of every
  issued Invoice number. Optional duration and due-day defaults are positive
  when present.
- Invoice snapshots are normalized, status/payment date agree, currencies are
  consistent, every line belongs to the Invoice Client, checked totals do not
  overflow, and no WorkItem is billed twice.

These checks run immediately before persistence even if the interface already
constrained the selection.

### Persistence Boundary

The complete mutation is inserted and saved as one user action. A failed save
keeps the recoverable editor draft visible and surfaces the error. The app never
reports a successful creation while only part of the graph has persisted.

Immediately before every controlled save, complete-graph validation rejects:

- A Horse without a Client or current Barn.
- An Appointment without a Barn.
- An AppointmentHorse without its Appointment or Horse.
- An Appointment without at least one valid AppointmentHorse.
- A joined Horse whose current Barn differs from the Appointment Barn.
- Duplicate Horse membership in one Appointment.
- A Visit without Appointment, Barn, startedAt, a nonempty name snapshot, or
  at least one VisitHorse.
- A VisitHorse without Visit or Horse.
- Duplicate Horse membership in one Visit.
- VisitHorse membership different from AppointmentHorse membership.
- An in-progress Visit with `completedAt`.
- A completed Visit with pending outcomes or no serviced Horse.
- `completedAt` earlier than `startedAt`.
- Work Notes on pending or not-serviced membership.
- A Photograph without an inverse-matching VisitHorse, with invalid dimensions
  or byte count, or with a duplicate UUID.
- A WorkItem without inverse-matching VisitHorse and Service, with an invalid
  snapshot or amount, or duplicated for one Service within a VisitHorse.
- Multiple Business Profiles, an invalid next-number sequence, or a nonpositive
  owner default.
- An Invoice without one Client, at least one InvoiceVisit and InvoiceLineItem,
  immutable valid snapshots, a valid status/payment pair, consistent USD
  currency, or one-to-one inverse-matching source WorkItems.

SwiftData relationship cardinality metadata is not the domain enforcement
boundary. Persistent-store integration tests verify in-progress and
completed reopening, correction, discard, relocation after completion, and
Invoice generation, status, deletion, and billing-link behavior after reopening.

Best-effort background saving calls the same Save Progress boundary. If the
same process resumes after failure, it may retain the dirty draft and surface
the error. If iOS terminates the process, neither the unsaved draft nor its
in-memory error survives; relaunch restores the last successful save.

## Calendar Semantics

`startDate` is stored as an absolute `Date`. Today grouping uses the user's
current calendar and time zone, calculating local day boundaries at query time.
Tests supply a fixed calendar and time zone, including a daylight-saving
boundary case.

`appointmentIntervalWeeks` is stored as an integer count of weeks. Its
six-week default does not create an appointment and does not infer an expected
duration.

`Visit.startedAt` is stored as an absolute Date captured once when Start Visit
succeeds and is the primary Horse History date. `Visit.completedAt` is captured
once when completion succeeds and must not precede `startedAt`.

Horse History contains completed Visits only and orders its projection by:

1. `Visit.startedAt` descending.
2. `Visit.completedAt` descending.
3. `serviceLocationNameSnapshot` ascending with localized comparison.
4. Horse name ascending with localized comparison.

No persisted UUID or ordering field is added solely for this tie-break.

## Explicit Exclusions

The first-shipping schema does not include:

- A Client–Barn relationship.
- Persisted photo paths, source filenames, source asset identifiers, EXIF,
  captions, classifications, thumbnails, or replacement history.
- Breed, age, sex, shoe size, veterinary data, or detailed medical data.
- Taxes, discounts, partial payments, payment processing, overdue automation,
  Draft or Sent invoice states, recurring invoices, statements, custom invoice
  numbering, logos, themes, or accounting integrations.
- Next-appointment records generated from an interval.
- A global default Client, Horse, Service Location, or Horse Service; these
  remain contextual record truth.
- Archive or generalized soft-delete fields.
- Synchronization, server identifiers, user accounts, or CloudKit metadata.
- Unscheduled Visit horses.
- Cancellation, no-show, or rescheduling state.
- Completed Visit deletion or historical-date correction.
- Background tasks, external draft files, or per-change autosave.

## Future Schema Evolution

After first shipment, every approved persisted change creates a new versioned
schema snapshot and an explicit migration stage from the shipping version. A
later slice may add models or fields only after its product rules, ownership,
deletion behavior, privacy implications, and migration defaults are defined.

Future capability is not pre-modeled. This avoids nullable speculative fields,
unstable enums, and identifiers without an owning domain. Migration tests for a
future shipping change must open the prior shipping store and verify that all
existing relationships and user data remain intact.
