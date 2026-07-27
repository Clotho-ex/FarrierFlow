# Slice 2 — Visit Completion Design

## Status

Approved product and architecture design for FarrierFlow Slice 2. This
specification shapes the slice only. It is not an implementation plan.

## Outcome

A farrier can start work from an existing Appointment, record an outcome for
every scheduled Horse, save an in-progress Visit, complete it, view the
completed Visit from the Appointment and Horse History, terminate the app, and
reopen the complete historical graph.

The primary flow is:

```text
Appointment Detail
→ Start Visit
→ Mark each scheduled Horse
→ Add optional per-Horse work notes
→ Complete Visit
→ View completed Visit
→ View it from Horse History
→ Terminate and relaunch
→ Verify the historical graph persisted
```

Slice 0 and Slice 1 remain frozen except for the V2 schema migration, Visit
relationships, Visit-aware delete rules, and the narrowly amended Horse
relocation rule defined here.

## Chosen Approach

Slice 2 adds dedicated `Visit` and `VisitHorse` models.

Appointment remains the scheduling record. Visit becomes the performed-work
record. This separation gives in-progress persistence, discard, completion,
correction, immutable service-location history, and Horse History clear
ownership without adding fields to `AppointmentHorse`.

The rejected alternatives are:

- Adding Visit outcomes directly to `AppointmentHorse`, which would conflate
  scheduled membership with performed work and make Visit discard and
  completion state ambiguous.
- Fully snapshotting Horse, Client, and service-location records, which would
  duplicate unrelated data and prematurely define a broader historical
  retention policy.

## Persisted V2 Schema

`FarrierFlowSchemaV2` is a complete versioned schema containing the five V1
models and the two new models:

1. Client
2. Barn
3. Horse
4. Appointment
5. AppointmentHorse
6. Visit
7. VisitHorse

Current application type aliases resolve to V2 after migration. V1 remains
available only as the prior schema snapshot.

### Visit

#### Persisted fields

| Field | Type | Rule |
| --- | --- | --- |
| `startedAt` | `Date` | Required and immutable after creation |
| `completedAt` | `Date?` | Nil in progress; set once on successful completion |
| `serviceLocationNameSnapshot` | `String` | Required, normalized, and immutable |
| `serviceLocationAddressSnapshot` | `String?` | Normalized and immutable |

Visit state is derived rather than redundantly persisted:

- `completedAt == nil` means in progress.
- `completedAt != nil` means completed.

Visit does not persist a separate status field.

#### Relationships

- `appointment: Appointment?` is the inverse of `Appointment.visit`.
  It is optional in SwiftData storage for iOS 18 deletion compatibility,
  required by the domain contract, and validated before every controlled save.
- `barn: Barn?` is the inverse of `Barn.visits`.
  It is optional in SwiftData storage for iOS 18 deletion compatibility,
  required by the domain contract, and validated before every controlled save.
- `visitHorses: [VisitHorse]` is the inverse of `VisitHorse.visit`.
  Visit owns this collection with a cascade delete rule and requires at least
  one valid membership.

The Barn reference preserves the identity of the current service-location
record. When it resolves, Visit Detail offers navigation to that record.
Historical Visit labels never derive from the current Barn name or address.

`serviceLocationNameSnapshot` and `serviceLocationAddressSnapshot` are captured
from the Appointment Barn only when Start Visit succeeds. Visit Detail and
Horse History always display the immutable snapshots. If `Visit.barn` is
unexpectedly missing, history remains readable and shows no service-location
navigation affordance.

No unrelated Barn fields are snapshotted.

### VisitHorse

#### Persisted fields

| Field | Type | Rule |
| --- | --- | --- |
| `outcomeRawValue` | `String` | Required; begins as `pending` |
| `workNotes` | `String?` | Normalized; allowed only when serviced |

A domain enum exposes exactly these outcomes:

- `pending`
- `serviced`
- `notServiced`

Persisted raw values are never displayed as user-facing copy. An unknown raw
value is invalid data and must produce a safe unavailable or error state.

#### Relationships

- `visit: Visit?` is the inverse of `Visit.visitHorses`.
  It is optional in SwiftData storage for iOS 18 deletion compatibility and
  required by the domain contract.
- `horse: Horse?` is the inverse of `Horse.visitHorses`.
  It is optional in SwiftData storage for iOS 18 deletion compatibility and
  required by the domain contract.

VisitHorse does not reference AppointmentHorse directly. Start Visit validates
that the VisitHorse Horse set exactly matches the AppointmentHorse Horse set
before saving.

### Existing-model additions

#### Appointment

- Add `visit: Visit?`, inverse of `Visit.appointment`.
- The to-one relationship expresses zero or one Visit per Appointment.
- The relationship uses a deny delete rule so an Appointment with any Visit
  cannot be deleted.

Existing Appointment fields and AppointmentHorse ownership otherwise remain
unchanged.

#### Barn

- Add `visits: [Visit]`, inverse of `Visit.barn`.
- The relationship uses a deny delete rule.
- Any in-progress or completed Visit blocks Barn deletion.

#### Horse

- Add `visitHorses: [VisitHorse]`, inverse of `VisitHorse.horse`.
- The relationship uses a deny delete rule.
- Visit history independently protects referenced Horses from deletion.

### Storage optionality and domain requiredness

The following V2 to-one relationships use optional SwiftData storage:

- `Visit.appointment`
- `Visit.barn`
- `VisitHorse.visit`
- `VisitHorse.horse`

They are optional only for deletion compatibility on iOS 18. Controlled
creation and mutation paths require every relationship and validate the
complete graph before saving. Views and feature models never force-unwrap
them.

Scalar requiredness is not weakened for deletion compatibility.
`Visit.startedAt` and `serviceLocationNameSnapshot` remain non-optional domain
data. `serviceLocationAddressSnapshot` remains optional because a Barn address
is optional.

## Ownership and Delete Rules

| Source relationship | Inverse | Delete rule | Result |
| --- | --- | --- | --- |
| `Appointment.visit` | `Visit.appointment` | Deny | An Appointment with a Visit cannot be deleted |
| `Visit.appointment` | `Appointment.visit` | Nullify | Discarding an allowed Visit clears the Appointment inverse |
| `Barn.visits` | `Visit.barn` | Deny | A Barn referenced by any Visit cannot be deleted |
| `Visit.barn` | `Barn.visits` | Nullify | Deleting an allowed Visit removes it from the Barn inverse |
| `Horse.visitHorses` | `VisitHorse.horse` | Deny | A Horse with Visit history cannot be deleted |
| `VisitHorse.horse` | `Horse.visitHorses` | Nullify | Deleting an owned membership preserves the Horse |
| `Visit.visitHorses` | `VisitHorse.visit` | Cascade | Discarding an in-progress Visit deletes only its VisitHorse records |
| `VisitHorse.visit` | `Visit.visitHorses` | Nullify | A membership never deletes its Visit |

Feature-model preflight checks remain required so blocked actions produce
specific native explanations before SwiftData enforces the deny rule.

Additional application rules are:

- Completed Visits have no delete or discard path.
- An in-progress Visit may be discarded with native confirmation.
- VisitHorse membership cannot be individually added, removed, or deleted
  after Start Visit.
- Discarding an in-progress Visit leaves its Appointment, AppointmentHorse,
  Barn, Horse, and Client records unchanged.
- Client deletion remains governed by its Horse relationships; no direct
  Client–Visit relationship is added.

## Start Visit

Appointment Detail offers Start Visit only when the Appointment has no Visit.

Before mutation, the Start Visit boundary must:

1. Resolve the Appointment and its Barn.
2. Confirm that the Appointment has no Visit.
3. Require at least one AppointmentHorse.
4. Resolve every AppointmentHorse and Horse relationship.
5. Reject duplicate Horse membership.
6. Confirm every scheduled Horse still belongs to the Appointment Barn.
7. Validate each Horse's required Client and current Barn.
8. Normalize and capture the Barn name and optional address.
9. Capture `startedAt` once from the supplied clock.

One persistence transaction then creates:

- The Visit.
- Its Appointment and Barn relationships.
- Its immutable service-location snapshots.
- One pending VisitHorse for every AppointmentHorse.
- Every required inverse relationship.

If validation or saving fails:

- No partial Visit or VisitHorse remains.
- The Appointment remains unchanged.
- Appointment Detail stays visible.
- A localized native error is presented.
- The action does not report that the Visit started.

## In-Progress Visit Editing

The Visit editor loads a feature-model draft from the last successfully saved
Visit state.

For every scheduled Horse it exposes:

- Horse identity.
- Pending, Serviced, or Not Serviced outcome.
- Work Notes when the Horse is serviced.

Changing a serviced Horse with nonempty Work Notes to pending or not serviced
requires confirmation before clearing those notes.

The editor exposes:

- Save Progress.
- Complete Visit.
- Discard Visit while the Visit is in progress.

### Dirty-state tracking

The feature model compares its draft with the last successfully persisted
Visit state.

When unsaved changes exist:

- The editor shows a clear unsaved-state indication.
- Dismissal requires confirmation.
- Discard Unsaved Changes restores the last successfully saved Visit state
  without deleting the Visit.
- Discard Visit remains a separate destructive action.
- Edits are never silently discarded.

## Save Progress

Save Progress validates the draft sufficiently for an in-progress Visit.

It requires:

- Valid Visit, Appointment, Barn, VisitHorse, and Horse relationships.
- A VisitHorse set exactly matching the AppointmentHorse set.
- Unique Horse membership.
- A known outcome value for every VisitHorse.
- Nil `completedAt`.
- Work Notes only for serviced Horses.

Pending outcomes are valid during Save Progress. At least one serviced Horse is
not required until completion.

A successful Save Progress:

- Persists the current VisitHorse outcomes and notes.
- Keeps the Visit in progress.
- Clears the dirty state only after the save succeeds.
- Keeps the editor open.

If saving fails:

- The in-memory draft and dirty state are preserved.
- The Visit remains in progress.
- A localized native error is shown.
- The underlying error is logged.
- The interface does not report the changes as saved.

## Background Save Limitation

When the app moves to the background, the editor makes a best-effort attempt to
save dirty Visit progress through the same Save Progress boundary.

If that attempt fails and the same application process later becomes active,
the editor can retain the dirty in-memory draft and surface the failure.

If iOS terminates the process:

- The unsaved in-memory draft is not recoverable.
- An in-memory background-save error cannot be presented after relaunch.
- Relaunch restores the last successfully persisted progress.

The app does not claim that background saving is guaranteed. Slice 2 adds no
background task, external draft file, per-change autosave, debounced
persistence, networking, or cloud recovery.

## Complete Visit

Complete Visit requires:

- Every VisitHorse is serviced or not serviced.
- At least one VisitHorse is serviced.
- Every Visit and VisitHorse relationship is valid.
- The VisitHorse Horse set exactly matches the AppointmentHorse Horse set.
- Horse membership is unique.
- Work Notes exist only for serviced Horses.
- `completedAt` is currently nil.

Completion captures `completedAt` once from the supplied clock. It must not be
earlier than `startedAt`.

The current draft and `completedAt` are validated and saved as one persistence
action. Completion is not reported unless that save succeeds.

On failure:

- The Visit remains in progress.
- `completedAt` remains nil.
- The draft and dirty state are preserved.
- A localized native error is presented.

## Completed Visit Correction

A completed Visit opens read-only with a standard Edit action.

Correction may change:

- Serviced or Not Serviced outcomes.
- Work Notes for serviced Horses.

Correction cannot change:

- Appointment, Barn, Horse, or membership relationships.
- `startedAt`.
- `completedAt`.
- Service-location snapshots.
- Visit completion state.

Pending is unavailable during completed correction. The corrected Visit must
still have at least one serviced Horse and satisfy every completion invariant.
Saving a correction is atomic and does not create a new start or completion
timestamp.

Completed Visits cannot be deleted in Slice 2.

## Appointment Rules After Visit Creation

Once any Visit exists:

- Appointment service location is read-only.
- AppointmentHorse membership is read-only.
- Scheduled start remains editable.
- Appointment notes remain editable.
- Expected duration remains editable.
- Appointment deletion is blocked.

The Appointment save boundary must prove that its Barn and Horse membership
still match the existing Visit before applying editable-field changes.

Editing `Appointment.startDate` does not change:

- `Visit.startedAt`.
- `Visit.completedAt`.
- Visit service-location snapshots.
- Visit Horse membership.
- Horse History ordering.

No Appointment edit may invalidate an existing Visit.

## Horse Relocation Amendment

Relocation evaluates every AppointmentHorse membership and its Appointment's
Visit state:

- Appointment with no Visit: blocks relocation.
- Appointment with an in-progress Visit: blocks relocation.
- Appointment with a completed Visit: does not block relocation.
- Missing or invalid Appointment or Visit relationships: fail closed and block
  relocation.

A past Appointment start date does not imply completion, cancellation, or
no-show. Any Appointment without a completed Visit blocks relocation regardless
of date.

The same rule powers:

- Horse editing.
- Add Existing Horse eligibility from Service Location Detail.

As a defensive invariant, any independently encountered in-progress VisitHorse
also blocks relocation.

Complete-graph validation changes narrowly:

- A Horse must currently match the Appointment Barn while the Appointment has
  no Visit or an in-progress Visit.
- After that Appointment's Visit is completed, a different
  `Horse.currentBarn` is valid because historical location is preserved by the
  Visit snapshots.

Relocation never changes Appointment, AppointmentHorse, Visit, VisitHorse, or
snapshot data.

Explicit cancellation, no-show, rescheduling, and automatic time-based
resolution remain outside Slice 2.

## Navigation and Presentation Ownership

No new tab is added.

### Appointment Detail

Appointment Detail owns the entry into Visit workflow:

- No Visit: Start Visit.
- In-progress Visit: Resume Visit.
- Completed Visit: View Visit.

Edit Appointment remains available with Barn and membership locked after Visit
creation. Attempting to delete an Appointment with a Visit presents a native
blocked-action explanation.

### Today and Schedule

Today and Schedule retain their existing date queries, grouping, and navigation
stacks.

Appointment rows add concise, localized In Progress or Completed secondary
status when a Visit exists. They remain appointment-focused and continue to
show scheduled time, service location, and Horses.

Completed Appointments remain visible only where the existing Today and
Schedule date rules include their scheduled start. Past Visit discovery is
owned by Horse History, not a new global destination.

### Visit Detail

Visit Detail displays:

- Work date from immutable `startedAt`.
- Immutable service-location name and optional address snapshots.
- In-progress or completed state.
- Every scheduled Horse and its outcome.
- Work Notes for serviced Horses when present.

When `Visit.barn` resolves, a standard navigation affordance opens the
current Service Location record. If it does not resolve, the immutable snapshot
remains readable and the affordance is absent.

## Horse History

Horse Detail gains a History section containing completed VisitHorse records
for that Horse. In-progress Visits do not appear.

Not-serviced outcomes remain visible because they are part of the completed
barn Visit record.

History ordering is:

1. `Visit.startedAt` descending.
2. `Visit.completedAt` descending.
3. `serviceLocationNameSnapshot` ascending using localized comparison.
4. Horse name ascending using localized comparison within the history
   projection.

No persisted UUID, sequence, or ordering field is added solely for
tie-breaking.

Each History row shows:

- Localized work date from `Visit.startedAt`.
- Immutable service-location name snapshot.
- Serviced or Not Serviced outcome.
- A concise indication when Work Notes exist.

Selecting a row opens the shared Visit Detail.

History loading distinguishes:

- Loading.
- Successfully loaded history.
- A legitimate empty result.
- Fetch failure with localized unavailable state and Retry.

A missing required relationship never crashes the view. Previously loaded
history is not replaced with a normal empty state when a fetch fails.

## Migration

The migration plan becomes:

- Schemas: `FarrierFlowSchemaV1`, `FarrierFlowSchemaV2`.
- Stage: lightweight V1-to-V2 migration.
- Current production, preview, in-memory test, and persistent-store test
  containers register V2.

The existing production store identity, configuration URL, and location remain
unchanged. Changing schema version must not create a new empty production store.

The migration:

- Preserves every existing Client, Barn, Horse, Appointment, and
  AppointmentHorse.
- Preserves every V1 inverse relationship.
- Adds empty Visit relationships.
- Creates no Visit or VisitHorse.
- Fabricates no historical snapshots.
- Leaves every existing Appointment without a Visit.

Therefore, existing appointments continue blocking Horse relocation until the
Appointment is deleted or a Visit is created and completed.

No custom migration callback or backfill is required for this additive schema.

If executable migration tests show that the additive models or optional
relationships cannot migrate safely on iOS 18, implementation must stop and
return for schema review. It must not silently recreate the store, drop data,
or introduce an unapproved custom migration.

## Validation Boundaries

### Start boundary

Validates the existing Appointment graph and constructs the complete Visit
graph before the first save.

### Draft boundary

Validates known outcomes, work-note eligibility, dirty state, and completion
readiness without mutating persistence.

### Domain boundary

Validates:

- One Visit per Appointment.
- Exact AppointmentHorse-to-VisitHorse Horse equality.
- Unique Horse membership.
- Required relationships.
- Snapshot requiredness.
- Timestamp invariants.
- Visit-state-specific outcome rules.
- Visit-aware Appointment editing.
- Visit-aware deletion and relocation.

### Persistence boundary

Start Visit, Save Progress, Complete Visit, Save Correction, and Discard Visit
each use one explicit save boundary. No action reports success before its save
succeeds.

Failed controlled writes restore or roll back persistence mutations without
destroying recoverable feature-model drafts.

## Invalid and Unavailable Data

Controlled application writes never create:

- Visit without Appointment or Barn.
- Visit without a nonempty normalized location-name snapshot.
- Visit without VisitHorse membership.
- VisitHorse without Visit or Horse.
- Duplicate Horse membership.
- Visit membership different from Appointment membership.
- In-progress Visit with `completedAt`.
- Completed Visit without `completedAt`.
- `completedAt` earlier than `startedAt`.
- Completed Visit with pending outcomes.
- Completed Visit with no serviced Horse.
- Work Notes on pending or not-serviced membership.

If invalid persisted data is read:

- Views render localized unavailable values or states.
- Feature models disable unsafe mutations.
- Missing Barn reference does not hide the immutable location snapshots.
- Unknown outcome raw values are not treated as a valid outcome.
- Underlying errors are logged without exposing implementation details.

Production container or migration failure remains visible. There is no
success-shaped in-memory fallback and no destructive store recreation.

## Accessibility and Localization

Slice 2 uses standard SwiftUI controls and native behavior:

- `NavigationStack`
- `List`
- `Form`
- `Section`
- `Picker`
- Toolbar actions
- Sheets or navigation destinations owned by the presenting feature
- Alerts and confirmation dialogs
- `ContentUnavailableView`

Requirements:

- Outcome controls announce Horse name, current outcome, and selection state.
- Work Notes have a visible localized label and explicit VoiceOver label.
- Pending, Serviced, Not Serviced, In Progress, and Completed use localized
  user-facing strings.
- Status is never communicated by color alone.
- Dates use the environment locale, calendar, and time zone.
- Persisted raw values never become display copy.
- Dynamic Type may wrap metadata without hiding outcomes or actions.
- Primary actions retain at least 44-by-44-point targets.
- Light Mode, Dark Mode, Increased Contrast, Reduce Motion, and one-handed
  field use remain required.

FarrierFlow remains English-only for this release. The string catalog and
formatting APIs remain localization-ready.

## Testing and Acceptance

### Unit and domain tests

- Visit state derivation.
- `startedAt` and `completedAt` invariants.
- Outcome raw-value decoding and invalid-value handling.
- Work-note normalization and outcome eligibility.
- Exact AppointmentHorse-to-VisitHorse copying.
- Dirty-state comparison.
- Save Progress validation.
- Completion and correction validation.
- Relocation for no Visit, in-progress Visit, and completed Visit.
- Past unstarted Appointment relocation blocking.
- Appointment field-lock rules after Visit creation.
- Horse History filtering and exact four-level ordering.

### SwiftData relationship and deletion tests

- V2 registers exactly seven models.
- All inverse relationships are present.
- All domain-required V2 to-one relationships use optional SwiftData storage.
- Delete rules match the V2 ownership matrix.
- Start Visit creates a complete graph atomically.
- Discard Visit cascades only VisitHorse.
- Appointment deletion is blocked while a Visit exists.
- Barn deletion is blocked while a Visit exists.
- Horse deletion is blocked while VisitHorse references it.
- Completed Visit has no application deletion path.
- Duplicate, missing, or mismatched Visit relationships fail validation.

### Migration tests

1. Create a real V1 store using the V1 schema.
2. Insert the complete connected-record graph.
3. Release every V1 container and context reference.
4. Open the same store through the V2 migration plan.
5. Verify every V1 record, field, and inverse relationship.
6. Verify no Visit or VisitHorse was fabricated.
7. Verify the existing Appointment still blocks relocation.
8. Start and complete a Visit in the migrated store.
9. Release and reopen the V2 store.
10. Verify the complete historical graph.

The migration gate runs on iOS 18 and iOS 26.

### Persistent-store reopening tests

- Start Visit and reopen with every VisitHorse pending.
- Save partial progress and reopen with the last successful outcomes and notes.
- Leave a dirty draft unsaved, recreate the process state, and verify only the
  last successful save returns.
- Complete Visit and reopen with timestamps, snapshots, outcomes, notes, and
  every inverse relationship.
- Correct a completed Visit and reopen with immutable timestamps unchanged.
- Relocate a Horse after completion and reopen with the new current Barn while
  historical snapshots remain unchanged.
- Discard an in-progress Visit and reopen with Appointment and
  AppointmentHorse intact.
- Delete-rule behavior remains correct after reopening.

### UI acceptance flow

1. Open an existing Appointment.
2. Start Visit.
3. Verify every scheduled Horse begins pending.
4. Mark each Horse serviced or not serviced.
5. Add optional Work Notes to a serviced Horse.
6. Save Progress.
7. Terminate and relaunch.
8. Verify the saved in-progress state.
9. Complete Visit.
10. View the completed Visit.
11. Open it from Horse History.
12. Terminate and relaunch.
13. Verify the complete historical graph persisted.

Additional UI coverage verifies:

- Completion blocked while an outcome remains pending.
- Completion blocked when no Horse is serviced.
- Unsaved-change dismissal confirmation.
- Separate in-progress Visit discard confirmation.
- Appointment, Barn, and Horse deletion blocks.
- Relocation blocked before completion and allowed afterward.
- Appointment scheduled-time correction leaves Visit history unchanged.
- Missing Barn reference retains readable snapshots without navigation.
- VoiceOver outcome and Work Notes labels.
- Dynamic Type, Light Mode, Dark Mode, Increased Contrast, and Reduce Motion.

The full unit and integration suite must pass on iOS 18 and iOS 26. The complete
UI suite runs on iOS 26, with focused compatibility coverage on iOS 18. Both
platform builds must report zero project diagnostics.

## Explicit Exclusions

Slice 2 does not introduce:

- Unscheduled Horses in a Visit.
- Cancellation, no-show, or rescheduling states.
- Time-based Appointment resolution.
- Services or structured work items.
- Visit-level general notes.
- Prices or Money.
- Hoof photographs.
- Invoices, payment status, or payment processing.
- Automatic next appointments.
- Notifications.
- Networking, accounts, CloudKit, synchronization, or backup.
- Background tasks or external draft files.
- Per-change or debounced autosave.
- Archive or generalized soft deletion.
- Completed Visit deletion.
- Historical date correction.
- Horse, Client, or unrelated Barn snapshots.
- Persisted ordering identifiers used only for display tie-breaking.
- A new tab.
- Custom navigation, custom controls, or custom Liquid Glass effects.

Later slices must shape these capabilities independently before adding models,
routes, directories, services, or abstractions.
