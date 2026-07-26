# FarrierFlow Data Model

## Scope

This document defines the complete SwiftData contract for the first vertical
slice. The graph supports independent clients and service locations, horses
owned by clients and currently located at one service location, and barn-centric
appointments containing one or more horses.

SwiftData is the local source of truth. No model in this schema represents
visits, hoof photographs, services, pricing, invoices, payments, subscriptions,
cloud synchronization, or backup.

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

“Barn” is the persisted domain name for any service location, including a
commercial barn, private stable, or client residence. User-facing copy may use
“Service Location” where that is clearer.

Required to-one relationships use nullable SwiftData storage where deletion
needs to clear an inverse safely on iOS 18. This is a persistence
representation detail only. It does not make those relationships optional to
the user or to the product domain. Controlled creation and mutation paths must
provide every required relationship and validate the complete graph before
saving.

## Schema Version

The first persisted graph is `FarrierFlowSchemaV1`. The declared fields below
are the complete V1 application schema; SwiftData supplies model identity.
Navigation uses SwiftData persistent identifiers and tests verify records by
their persisted fields and relationships.

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

A client may be deleted only when `horses` is empty. When horses reference the
client, the feature model prevents deletion and presents a native alert
explaining that the horses must be reassigned or removed first. Horses never
cascade from a client deletion.

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
- There is no direct relationship to `Client`.
- Neither relationship cascades.

### Validation

- `name`, after trimming surrounding whitespace and newlines, must not be
  empty.
- Optional text fields store `nil` when their normalized value is empty.
- An address is not required to create a service location. Navigation or
  mapping actions remain unavailable until an address exists.

### Deletion

A barn may be deleted only when both `horses` and `appointments` are empty. If
either relationship exists, the feature model prevents deletion and presents a
native alert naming the records that must be reassigned or removed. Barn
deletion never cascades to horses or appointments.

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

`currentBarn` may change only when `appointmentHorses` is empty. If any
`AppointmentHorse` references the horse, the feature model prevents the change,
keeps the existing barn, and presents a native alert explaining why relocation
is blocked.

Add Existing Horse from a service-location detail applies the same rule. Its
eligible set contains only horses whose `appointmentHorses` collection is empty
and whose `currentBarn` is not already the destination barn.

Relocation never moves, deletes, retargets, or otherwise rewrites an existing
Appointment or AppointmentHorse.

### Deletion

A horse may be deleted only when `appointmentHorses` is empty. If any
appointment references it, the feature model prevents deletion and explains
that referenced horses cannot be removed in this slice. Deleting a horse never
deletes its client, barn, appointment, or join records.

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
- Appointment owns the persistence lifetime of its join records.
- Appointment does not own Barn, Horse, or Client.

### Validation

- `barn` must resolve to a persisted record in the editing context.
- `startDate` is an absolute date and time. There is no required end date.
- `notes` stores `nil` when its normalized value is empty.
- `expectedDurationMinutes` is either `nil` or greater than zero.
- The appointment must contain at least one `AppointmentHorse`.
- Every joined horse's `currentBarn` must equal the appointment's `barn`.
- The same horse may appear no more than once in an appointment.

Expected duration is not derived from horse count and is not populated
automatically. When it is absent, Today and Schedule display only the start
time.

### Deletion

Deleting an appointment cascades only to its `AppointmentHorse` records. It
never deletes its barn, horses, or clients.

## AppointmentHorse

### Fields

AppointmentHorse has no scalar application fields in V1.

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

SwiftData relationship metadata does not replace the uniqueness check. The
appointment feature model prevents duplicate selection before inserting a join
and validates the complete set again before saving.

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

Feature-model preflight checks are required even where the SwiftData delete rule
also denies deletion. The preflight provides a clear user explanation; the
schema rule protects the graph if a call site bypasses that interface.
The Nullify entries for required domain relationships are enabled by their
optional SwiftData storage. They support safe inverse cleanup during deletion;
they do not permit controlled application writes to omit a relationship.

## Validation Boundaries

### Editor Boundary

Editors normalize strings, require mandatory selections, validate positive
numeric values, and disable Save until their draft is locally valid.

### Domain Boundary

Domain rules validate relationships that span models:

- Appointment has at least one horse.
- Appointment horses are unique.
- Appointment horses currently belong to the selected barn.
- Horse relocation is allowed only when the horse has no appointment
  memberships.
- An Add Existing Horse candidate has no appointment memberships and is not
  already assigned to the destination barn.
- Delete preconditions are satisfied.

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

SwiftData relationship cardinality metadata is not the domain enforcement
boundary. Persistent-store integration tests verify both valid graph reopening
and appointment deletion followed by reopening.

## Calendar Semantics

`startDate` is stored as an absolute `Date`. Today grouping uses the user's
current calendar and time zone, calculating local day boundaries at query time.
Tests supply a fixed calendar and time zone, including a daylight-saving
boundary case.

`appointmentIntervalWeeks` is stored as an integer count of weeks. Its
six-week default does not create an appointment and does not infer an expected
duration.

## Explicit Exclusions

The V1 schema does not include:

- A Client–Barn relationship.
- Profile photos or photo paths.
- A service catalog or default service.
- Breed, age, sex, shoe size, veterinary data, or detailed medical data.
- Visit or work-performed records.
- Pricing, invoices, payment status, or payment processing.
- Next-appointment records generated from an interval.
- Archive or generalized soft-delete fields.
- Synchronization, server identifiers, user accounts, or CloudKit metadata.

## Future Schema Evolution

Every approved persisted change creates a new versioned schema snapshot and an
explicit migration stage from the previous version. A later slice may add new
models or fields only after its product rules, ownership, deletion behavior,
privacy implications, and migration defaults are defined.

Future capability is not pre-modeled in V1. This avoids nullable speculative
fields, unstable enums, and identifiers without an owning domain. Migration
tests will open a prior-version store, migrate it, and verify that all existing
relationships and user data remain intact.
