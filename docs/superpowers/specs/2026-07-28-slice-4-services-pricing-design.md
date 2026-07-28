# Slice 4 — Services and Pricing Design

**Status:** Approved product and architecture design

**Date:** 2026-07-28

## Purpose

Slice 4 adds a reusable Service catalog, an optional default Service for each
Horse, and priced WorkItems owned by individual VisitHorse records.

A farrier can:

1. Create and maintain reusable Services.
2. Assign one active default Service to a Horse.
3. Start a Visit and receive one draft WorkItem from that Horse default.
4. Add, remove, replace, or deliberately reprice performed work.
5. Complete the Visit only when every serviced Horse has valid work.
6. Reopen Visit Detail and Horse History with the original service names and
   amounts intact after the catalog changes.

Slice 4 establishes performed-work and price history for later invoicing. It
does not design or implement invoices.

## Approved Approach

Use a global Service record plus a VisitHorse-owned WorkItem that retains the
Service relationship and copies historical snapshots.

Each WorkItem stores:

- The selected Service relationship.
- An immutable service-name snapshot.
- A correctable amount in integer minor units.
- An immutable explicit `USD` currency-code snapshot.
- One VisitHorse owner.

This is the smallest approach that satisfies both reusable catalog behavior and
historical integrity.

Two alternatives are rejected:

1. Snapshot-only WorkItems cannot enforce the rule that a historically
   referenced Service may not be deleted and cannot navigate back to an
   archived Service.
2. Live catalog-linked WorkItems without snapshots would let catalog rename or
   repricing rewrite completed Visit history.

## Product Boundary

Every WorkItem belongs to exactly one VisitHorse.

A WorkItem records one Service performed, or intended to be performed, for one
specific Horse during one Visit.

Slice 4 supports no Visit-owned charge. Defer:

- Barn-call fees.
- Travel fees.
- Mileage.
- Emergency or after-hours fees.
- Shared Appointment charges.
- Generic adjustments.

Do not:

- Attach WorkItems directly to Visit.
- Add polymorphic ownership.
- Add a generic charge superclass.
- Divide Visit-level charges among Horses.
- Add invoice-only charge placeholders.
- Add fields intended only for future travel or call-out fees.

Slice 5 must separately shape Visit-level charges and invoice ownership without
changing the historical meaning of Slice 4 WorkItems.

## Versioned SwiftData Schema V4

Preserve `FarrierFlowSchemaV1`, `FarrierFlowSchemaV2`, and
`FarrierFlowSchemaV3` as immutable prior snapshots.

Add a complete `FarrierFlowSchemaV4` with ten model types:

1. Client
2. Barn
3. Horse
4. Appointment
5. AppointmentHorse
6. Visit
7. VisitHorse
8. Photograph
9. Service
10. WorkItem

Current application aliases and every production, preview, in-memory test, and
persistent-store test container resolve to V4 after migration.

### Service

#### Persisted fields

| Field | Type | Contract |
| --- | --- | --- |
| `name` | `String` | Required normalized nonempty name |
| `defaultAmountMinorUnits` | `Int64` | Required nonnegative default amount |
| `currencyCode` | `String` | Required; exactly `USD` in Slice 4 |
| `isArchived` | `Bool` | Required; false at creation |

Service does not persist:

- Description.
- Category.
- Duration.
- Tax behavior.
- SKU or service code.
- Customer-facing copy.
- Invoice behavior.
- Quantity behavior.
- Travel or call-out behavior.

#### Relationships

- `horsesUsingAsDefault: [Horse]` is the inverse of
  `Horse.defaultService`.
- `workItems: [WorkItem]` is the inverse of `WorkItem.service`.

Service owns neither Horse nor WorkItem persistence lifetime.

### WorkItem

#### Persisted fields

| Field | Type | Contract |
| --- | --- | --- |
| `serviceNameSnapshot` | `String` | Required normalized name copied at creation |
| `amountMinorUnits` | `Int64` | Required nonnegative amount |
| `currencyCode` | `String` | Required; copied as `USD` |

#### Relationships

- `service: Service?` is the inverse of `Service.workItems`.
- `visitHorse: VisitHorse?` is the inverse of
  `VisitHorse.workItems`.

Both relationships use optional SwiftData storage where required by the
established iOS 18 deletion-safe inverse strategy. Both remain required by the
domain contract. Controlled creation always supplies both relationships.

WorkItem does not persist:

- Quantity.
- Unit price.
- Tax.
- Discount.
- Adjustment kind.
- Visit relationship.
- Horse relationship.
- Appointment relationship.
- Invoice relationship.
- Invoice lock.
- Manual description.
- Sort index.

### Existing-model additions

#### Visit

Add:

- `workItemPolicyVersion: Int`, required and immutable after creation or
  migration, with a migration-safe property default of `0`.

Exactly two persisted values are supported:

- `0` — Legacy Visit policy.
- `1` — Slice 4 WorkItem-required policy.

Every Visit migrated from V1, V2, or V3 receives `0`. Every Visit created after
Slice 4 ships explicitly receives `1` during Start Visit. The creation path
must not rely only on the property default.

The value is a narrow compatibility discriminator for Visit completion rules.
Slice 4 does not add a generalized policy framework, policy model, or
user-editable policy state. Any value other than `0` or `1` is invalid and
fails closed.

#### Horse

Add:

- `defaultService: Service?`, inverse of
  `Service.horsesUsingAsDefault`.

This relationship is genuinely optional in both storage and domain behavior.
When present, it must resolve to an active valid Service.

#### VisitHorse

Add:

- `workItems: [WorkItem]`, inverse of `WorkItem.visitHorse`.

VisitHorse owns WorkItem persistence lifetime through cascade deletion.

The collection may be empty for:

- A Pending VisitHorse.
- An in-progress Serviced VisitHorse not yet ready for completion.
- A Not Serviced VisitHorse.
- A VisitHorse on a legacy policy-`0` Visit, including completed Serviced
  history migrated from V1, V2, or V3.

## Ownership and Delete Rules

| Source relationship | Inverse | Delete rule | Result |
| --- | --- | --- | --- |
| `Service.horsesUsingAsDefault` | `Horse.defaultService` | Deny | Service cannot be deleted while any Horse uses it as default |
| `Horse.defaultService` | `Service.horsesUsingAsDefault` | Nullify | Deleting an otherwise eligible Horse preserves Service |
| `Service.workItems` | `WorkItem.service` | Deny | Service cannot be deleted while any WorkItem references it |
| `WorkItem.service` | `Service.workItems` | Nullify | Deleting WorkItem preserves Service |
| `VisitHorse.workItems` | `WorkItem.visitHorse` | Cascade | Deleting an owned VisitHorse deletes its WorkItems |
| `WorkItem.visitHorse` | `VisitHorse.workItems` | Nullify | Deleting WorkItem preserves VisitHorse |

All existing V3 relationships and delete rules remain unchanged.

Feature-owned preflight remains required even where SwiftData also denies
deletion. Preflight supplies a specific user-facing explanation; schema rules
protect the graph if a call site bypasses that interface.

## Service Catalog Semantics

Service is a global reusable business record. It is not scoped to Client, Barn,
Horse, Appointment, or Visit.

### Creation

Creation requires:

- A normalized nonempty name.
- A valid nonnegative USD default amount.
- Explicit persisted currency code `USD`.

New Services begin active.

Service names are not required to be unique. Service identity remains the
SwiftData record identity. Selection rows include localized default price so
same-name records remain distinguishable where their prices differ.

### Editing

Editing may change:

- Name.
- Default amount.

Editing never changes:

- Existing WorkItem service-name snapshots.
- Existing WorkItem amounts.
- Existing WorkItem currency snapshots.
- Existing Visit totals.
- Horse History.

Horse defaults continue referencing the same Service identity. Therefore a
rename or reprice affects WorkItems created for those Horses in future Visits
only.

### Archive

Archive is an explicit reversible lifecycle action.

A Service may not be archived while any Horse uses it as a default. The user
must explicitly clear or replace every affected Horse default first.

Archive does not:

- Clear Horse defaults automatically.
- Delete or rewrite WorkItems.
- Substitute another Service.
- Change WorkItem snapshots.

Archived Services:

- Remain visible in the Archived catalog section.
- Remain reachable from historical WorkItems.
- Remain valid references for existing in-progress and completed WorkItems.
- Are excluded from new WorkItem selection.
- Are excluded from Horse default selection.

Reactivate restores the Service to future WorkItem and Horse-default selection.
It does not modify existing WorkItems or assign any Horse default.

### Permanent deletion

An unreferenced active or archived Service may be permanently deleted after
destructive confirmation.

Deletion is blocked when either relationship is nonempty:

- `horsesUsingAsDefault`
- `workItems`

Any persisted WorkItem blocks deletion, whether its Visit is in progress or
completed. Deletion never cascades into Horse, VisitHorse, Visit, or history.

## One WorkItem per Service per VisitHorse

A VisitHorse may own multiple WorkItems, but each must reference a different
Service.

The pair `(VisitHorse, Service)` is unique.

SwiftData relationship metadata does not replace application-level uniqueness
validation. Uniqueness compares resolved Service persistent identities within
one VisitHorse.

Enforce uniqueness during:

- Default WorkItem creation at Start Visit.
- Manual WorkItem addition.
- Service replacement.
- Save Progress.
- Visit completion.
- Completed Visit correction.
- Complete-domain graph validation.
- Persistent-store reopening validation.

### Selection behavior

Add Service excludes every Service already represented by another WorkItem for
that VisitHorse.

When a Horse default created the initial WorkItem, that Service is absent from
the Add Service picker.

Replacing a WorkItem:

- May retain its current Service as a no-op.
- Excludes every Service represented by another WorkItem for the same
  VisitHorse.
- Uses only active Services as replacement candidates.

### Duplicate invalid data

A duplicate pair encountered in persisted data is invalid.

The app must:

- Fail closed.
- Disable unsafe save, completion, or correction.
- Present an unavailable or recoverable error state.
- Log the structural violation locally.

The app must not:

- Merge duplicate WorkItems.
- Delete one silently.
- Add their prices together as units.
- Interpret the duplicate count as quantity.
- Rewrite ownership or Service identity.

If repeated units become a real product requirement, quantity must be shaped
explicitly in a later slice.

## WorkItem Identity and Snapshots

### Creation

Creating a WorkItem from an active Service copies:

- Service relationship.
- Normalized Service name into `serviceNameSnapshot`.
- Service default amount into `amountMinorUnits`.
- Service currency code into `currencyCode`.
- VisitHorse ownership.

The Service relationship, VisitHorse ownership, service-name snapshot, and
currency snapshot do not change in place through supported operations.

### Amount override

The farrier may deliberately change `amountMinorUnits`:

- Before in-progress Visit persistence.
- Before Visit completion.
- During allowed completed Visit correction.

Zero is valid and means complimentary work.

This correctability means amount is not permanently immutable in Slice 4.
Historical integrity means catalog changes cannot rewrite it. Only an explicit
Visit edit may do so.

### Service replacement

Replacing Service is represented as one atomic draft mutation:

1. Remove the prior WorkItem.
2. Create a replacement WorkItem from the chosen active Service.
3. Copy the new Service name, default amount, and currency.
4. Revalidate `(VisitHorse, Service)` uniqueness.
5. Allow a deliberate amount override after replacement.

No supported production path mutates an existing WorkItem's Service
relationship or service-name snapshot in place.

### Catalog changes after creation

Service rename, repricing, archive, Reactivate, or blocked deletion does not
change any existing WorkItem field.

An existing WorkItem referencing an archived Service:

- Remains readable.
- May have its amount corrected.
- May be removed.
- May be replaced with an active Service.
- Cannot be duplicated through Add Service.

## Exact USD Price Entry

Slice 4 is English-only and U.S.-first.

Price-entry parsing uses the `en-US` locale. Foundation may represent this
locale identifier as `en_US`; the parsing grammar remains the U.S. grammar
defined here.

### Accepted grammar

After trimming surrounding whitespace, input consists of:

1. An optional leading `$`.
2. A required whole-number portion.
3. Optional valid grouping commas.
4. An optional decimal point.
5. Zero, one, or two fractional digits.

No internal whitespace is accepted. If `$` is present, it immediately precedes
the numeric portion.

Valid whole-number forms are:

- Ungrouped digits: `0`, `12`, `1250`
- Grouped digits with one-to-three leading digits followed by one or more
  three-digit groups: `1,250`, `12,500`, `1,250,000`

Examples that may be accepted:

- `0`
- `12`
- `12.`
- `12.5`
- `12.50`
- `$12.50`
- `1,250.00`
- Surrounding-whitespace versions of valid input

### Rejected input

Reject:

- Empty or whitespace-only input.
- A standalone `$`.
- Negative signs.
- Positive signs.
- Parenthesized negatives.
- More than two fractional digits.
- A leading decimal point without whole digits.
- Malformed grouping such as `12,50`, `1,25,000`, or `1,,250`.
- Scientific notation.
- Currency codes such as `USD 12` or `12 USD`.
- Unsupported decimal or grouping separators.
- Internal whitespace such as `$ 12.50`.
- Alphabetic text.
- Values that cannot fit checked `Int64` minor units.

### Exact conversion

Conversion must use exact integer or decimal arithmetic.

One valid exact strategy is:

1. Trim surrounding whitespace.
2. Validate the full grammar before numeric conversion.
3. Remove optional `$` and grouping commas.
4. Split whole and fractional components at the decimal point.
5. Parse whole digits without floating point.
6. Right-pad the fractional component to two digits.
7. Compute `whole × 100 + fraction` with checked multiplication and addition.
8. Reject any parse, multiplication, or addition overflow.

Transient `Decimal` or `NumberFormatter` use is permitted only when exactness
and the grammar above are preserved.

Do not use `Double` or `Float`.

Persist only:

- `Int64` minor units.
- Explicit `USD` currency code.

## USD Formatting

Display nonzero amounts through localized Foundation currency formatting using
currency code `USD`.

Display a zero WorkItem with localized user-facing copy such as
“Complimentary,” not raw cents or a persistence value.

A nonempty all-zero WorkItem subtotal may also display “Complimentary.”

User-facing explanatory copy says “US dollars” where currency context is
needed. Raw `USD`, raw integer cents, parsing grammar, or persistence enum
values do not become untranslated display copy.

Formatting locale may follow the current presentation locale. Parsing remains
fixed to `en-US` for Slice 4.

## Checked Totals

Totals are derived and never persisted.

- A VisitHorse subtotal with recorded WorkItems is the sum of their amounts.
- When every required subtotal is available, Visit total is the sum of every
  VisitHorse subtotal.
- Completed Visit totals contain only Serviced WorkItems because Not Serviced
  VisitHorses must contain none.
- In-progress totals may include WorkItems owned by Pending or Serviced
  VisitHorses.

For a completed policy-`0` Visit, a Serviced VisitHorse with no WorkItems has
an unavailable subtotal, not a zero subtotal. If any Serviced VisitHorse has
no recorded WorkItems, the complete Visit total is also unavailable.
Validation still checks every recorded WorkItem and every sum that can be
formed; the interface never presents a partial recorded sum as the complete
historical total.

Every sum uses checked `Int64` addition. No intermediate or final operation may
wrap, clamp, saturate, truncate, or convert through floating point.

Validate checked totals during:

- Default WorkItem creation at Start Visit.
- Manual WorkItem addition.
- Amount override.
- Service replacement.
- Save Progress.
- Completion.
- Completed correction.
- Domain-graph validation.
- Persistent reopening.

If a controlled draft overflows:

- Block Save Progress, completion, or correction.
- Keep every draft edit and amount visible.
- Explain that one or more amounts must be reduced.
- Persist no partial mutation.

If persisted data overflows on reopening:

- Treat the aggregate as invalid.
- Never show a wrapped or approximate total.
- Fail closed for unsafe mutation.
- Present an unavailable state and log the structural failure.

## Horse Default Service

A Horse has zero or one default Service.

Only an active valid Service may be selected.

Horse editor provides:

- None.
- Every active Service.
- No archived Service.

Changing default affects future Start Visit operations only. It never changes:

- Existing Appointment.
- Existing VisitHorse.
- Existing WorkItem.
- Completed history.

A Service may not be archived while referenced as a default. Archive never
clears defaults automatically.

Existing migrated Horses begin with no default Service.

## Start Visit

Start Visit remains one atomic persistence action.

Before mutation, retain all existing Appointment, Barn, Horse, membership,
snapshot, and uniqueness validation. Add:

1. Create the Visit with `workItemPolicyVersion` explicitly set to `1`.
2. Resolve each Horse default Service.
3. Require every non-nil default to be active and valid.
4. Create one VisitHorse for every AppointmentHorse.
5. For each non-nil default, create exactly one WorkItem.
6. Copy Service identity, normalized name, default amount, and `USD`.
7. Validate `(VisitHorse, Service)` uniqueness.
8. Validate WorkItem relationships, snapshots, amounts, and currency.
9. Validate every checked subtotal and Visit total.
10. Save the complete Visit, VisitHorse, and WorkItem graph once.

If any default Service is missing, archived, invalid, inverse-mismatched, or
would produce invalid WorkItem data:

- Roll back the whole Start Visit action.
- Leave Appointment unchanged.
- Create no partial Visit, VisitHorse, or WorkItem.
- Present a localized recoverable error.

The Visit, every VisitHorse, and every default WorkItem are inserted and saved
in the same atomic transaction. A failed action persists none of them.

Existing migrated Visits retain policy `0`. Their VisitHorses receive no
fabricated WorkItems.

## In-Progress Visit Editing

Visit draft expands to include WorkItem drafts separate from SwiftData state.

For each Horse, the editor supports:

- Outcome.
- Work Notes where permitted.
- Existing WorkItems.
- Add Service from active eligible Services.
- Remove WorkItem.
- Replace Service.
- Deliberate amount override.
- Derived subtotal.
- Existing Hoof Photographs navigation.

WorkItem draft changes are persisted only through explicit Visit save
boundaries. Photograph operations remain independently persisted through the
existing Photograph feature.

### Pending

Under either policy, Pending may contain zero or more valid WorkItems while the
Visit remains in progress.

### Serviced

An in-progress Serviced VisitHorse may temporarily contain zero WorkItems while
the farrier edits or saves progress. On a policy-`1` Visit, it must contain at
least one valid WorkItem before completion. A policy-`0` Visit may complete
with zero or more valid WorkItems for a Serviced VisitHorse.

### Not Serviced

Not Serviced must contain zero WorkItems at every save boundary.

Changing Pending or Serviced to Not Serviced when WorkItems exist requires
destructive confirmation.

If Work Notes also exist, one confirmation explains that WorkItems and Work
Notes will be cleared.

Confirming:

- Applies Not Serviced.
- Clears every WorkItem.
- Clears Work Notes.

Cancelling preserves:

- Existing outcome.
- Work Notes.
- Every WorkItem.
- Every selected Service.
- Every amount override.

Changing Serviced to Pending retains WorkItems but follows the existing Work
Notes clearing rule.

## Save Progress

Save Progress permits Pending outcomes.

It requires:

- Existing Visit and membership invariants.
- A supported immutable `workItemPolicyVersion` of `0` or `1`.
- Valid WorkItem ownership and inverse relationships.
- Valid Service relationships.
- Unique `(VisitHorse, Service)` pairs.
- Valid normalized snapshots.
- Nonnegative amounts.
- `USD` currency.
- No WorkItems on Not Serviced VisitHorses.
- Checked non-overflowing totals.
- Existing Work Notes eligibility.

Save Progress does not require every Serviced VisitHorse to have a WorkItem.
The policy-`1` minimum belongs to completion.

One persistence action applies WorkItem insertion, deletion, replacement,
amount override, outcomes, and Work Notes.

Failure:

- Rolls back persistence mutation.
- Keeps the in-memory Visit draft.
- Keeps every amount override and Service selection.
- Keeps Visit in progress.
- Reports no success-shaped state.

## Complete Visit

Completion retains every existing V3 invariant and additionally requires:

- `workItemPolicyVersion` is exactly `0` or `1`.
- Every VisitHorse is Serviced or Not Serviced.
- At least one VisitHorse is Serviced.
- Every Not Serviced VisitHorse has zero WorkItems.
- Every WorkItem resolves one VisitHorse and one Service.
- Every `(VisitHorse, Service)` pair is unique.
- Every snapshot is valid.
- Every amount is nonnegative.
- Every currency code is `USD`.
- Every subtotal and Visit total completes without overflow.

The WorkItem-count rule for a completed Serviced VisitHorse depends only on the
Visit's immutable policy:

- Policy `0`: zero or more valid WorkItems are allowed.
- Policy `1`: at least one valid WorkItem is required.

Policy `0` preserves valid pre-Slice-4 history without inferring or fabricating
performed work. Unknown policy values fail closed.

The current draft and `completedAt` are saved atomically. Completion is not
reported unless the save succeeds.

## Completed Visit Correction

Completed correction may:

- Add WorkItems from active Services.
- Remove WorkItems.
- Replace a WorkItem Service.
- Change WorkItem amounts, including zero.
- Change Serviced and Not Serviced outcomes.
- Clear WorkItems after destructive confirmation.

Pending remains unavailable.

Correction must preserve:

- Appointment relationship.
- Barn relationship.
- Horse and VisitHorse membership.
- VisitHorse ownership.
- `workItemPolicyVersion`.
- `startedAt`.
- `completedAt`.
- Service-location snapshots.
- Photograph ownership and metadata.
- Completed Visit state.

Correction must continue satisfying every completion and WorkItem invariant,
including policy-specific Serviced requirements, pair uniqueness, and checked
totals.

A legacy Visit remains policy `0` throughout correction. A Serviced
VisitHorse may remain without WorkItems, although the farrier may add known
WorkItems. The app does not force invention of historical work.

A Slice 4 Visit remains policy `1` throughout correction and every Serviced
VisitHorse must continue owning at least one valid WorkItem.

No correction path upgrades, downgrades, or otherwise edits the policy value.

Existing WorkItems referencing archived Services remain valid during
correction. They may be repriced, removed, or replaced. Archived Services
cannot be selected for a new or replacement WorkItem.

Until Slice 5:

- Completed WorkItems remain correctable.
- No invoice lock exists.
- No invoice relationship or lock field is added.

Slice 5 must define when invoiced work becomes locked and whether an invoice
snapshots or owns its own line items.

## Historical Integrity

Catalog rename does not rewrite WorkItem service-name snapshots.

Catalog repricing does not rewrite WorkItem amounts.

Catalog archive does not rewrite or remove WorkItems.

Horse default changes affect future Start Visit actions only.

Horse relocation does not change WorkItems.

Visit migration and completed correction do not rewrite
`workItemPolicyVersion`.

Policy `0` preserves the absence of structured WorkItems as unknown historical
detail. It does not mean that no work was performed.

WorkItem ownership never moves between VisitHorses.

Service replacement creates a replacement WorkItem within the same owning
VisitHorse and never retargets the old WorkItem.

Only explicit Visit correction may change completed work or prices.

Historical WorkItem display uses snapshots. When the Service relationship
resolves, the interface may navigate to current Service Detail, including an
archived Service. If the relationship is unexpectedly missing, snapshots may
remain readable without navigation, but the graph remains invalid for unsafe
mutation.

## Deterministic Ordering

No ordering field is persisted solely for display.

Service catalog order:

1. Active section before Archived section.
2. Name ascending using localized case- and diacritic-insensitive comparison.
3. Default amount ascending.
4. Persistent identifier ascending.

WorkItem order within one VisitHorse:

1. Service-name snapshot ascending using localized case- and
   diacritic-insensitive comparison.
2. Amount ascending.
3. Service persistent identifier ascending.
4. WorkItem persistent identifier ascending.

The same order is used after Save Progress, completion, correction, and
persistent reopening.

## Navigation and Interface

No new tab is added.

### Services destination

Add Services to the existing Clients toolbar More menu beside Service
Locations.

Services uses a native `List` with Active and Archived sections.

States:

- No Services: explain the catalog and offer Add Service.
- No Active Services with archived records: explain that future work requires
  an active Service.
- Loading where needed.
- Fetch failure with unavailable state and Retry.

Service row displays:

- Name.
- Localized default amount or Complimentary.
- Archived state where applicable.

### Service Detail

Service Detail displays:

- Name.
- Localized default amount.
- Active or Archived status.
- Horses currently using Service as default.
- Navigation to those Horse records.
- Edit.
- Archive or Reactivate.
- Permanent delete when permitted.

Blocked archive explains that Horse defaults must be cleared or replaced.
Blocked deletion distinguishes Horse-default references from WorkItem history.

### Service editor

Use native `Form` with:

- Required Name.
- Required Price.
- Supporting copy that prices use US dollars.
- Inline parsing or validation feedback.
- Save disabled while invalid.

Edit changes future defaults only. It does not display or imply a historical
rewrite.

### Horse editor and detail

Horse editor adds optional Default Service picker:

- None.
- Active Services only.
- Name and localized default amount.

Horse Detail displays selected default or Not Set.

When no active Services exist, None remains available and guidance points to
Clients, More, Services.

### Visit editor

Each Horse section contains:

- Outcome.
- Work Notes where permitted.
- Services list for Pending or Serviced.
- Add Service.
- Derived subtotal.
- Hoof Photographs navigation.

Not Serviced exposes no Add Service action and owns no WorkItems.

WorkItem row displays:

- Service-name snapshot.
- Localized amount or Complimentary.
- Archived status when an existing line references an archived Service.

Selecting WorkItem opens native edit presentation for:

- Exact USD amount override.
- Service replacement from eligible active Services.
- WorkItem removal.

Add Service picker:

- Includes active Services only.
- Excludes Services already represented for that VisitHorse.
- Shows name and localized default amount.
- Provides a clear no-active-or-eligible-Service state.

Slice 4 does not add nested Service creation inside Visit editing. Catalog
creation remains in Services.

### Completed Visit Detail

Each Horse section shows:

- Outcome.
- WorkItems and localized amounts.
- Work Notes.
- Derived Horse subtotal.
- Hoof Photographs destination.

Visit Detail shows a checked derived Visit total.

A legacy policy-`0` Serviced Horse with no WorkItems still shows the Serviced
outcome and no fabricated service lines. Its subtotal is omitted or shown as
unavailable rather than as zero or Complimentary. If explanatory copy is
needed, use “No recorded services.” The interface must not imply that no work
was performed merely because structured WorkItems are absent.

If any Serviced Horse on that Visit has no recorded WorkItems, Visit Detail
shows the total as unavailable rather than presenting a partial sum as the
complete Visit total.

A WorkItem may navigate to current Service Detail when the relationship
resolves. Snapshot display remains authoritative for historical name and
amount.

### Horse History

Horse History rows add:

- WorkItem count for Serviced outcomes.
- Derived Horse subtotal.

For a legacy policy-`0` Serviced Horse with no WorkItems, omit the count and
subtotal or present the subtotal as unavailable. Do not show zero services,
zero dollars, or Complimentary in a way that implies no work occurred.

Selecting a row still opens shared Visit Detail. No global work-history or
invoice destination is added.

## Architecture and Feature Ownership

Keep the existing dependency direction:

```text
SwiftUI View
    ↓
@Observable feature model
    ↓
Domain rule or use case
    ↓
SwiftData ModelContext
```

Feature ownership:

- Services owns catalog list, detail, editor, archive, Reactivate, deletion,
  and catalog validation.
- Horses owns default-Service selection.
- Visits owns WorkItem drafts, addition, replacement, removal, amount override,
  outcome integration, completion, and correction.
- Core/Persistence owns V4 schema, migration, complete-graph validation, and
  delete-rule protection.
- Small pure money parsing, formatting, and checked-total rules may be shared
  because both Services and Visits actively require them.

Views do not:

- Parse or total money.
- Fetch or save SwiftData directly to enforce business rules.
- Mutate WorkItem ownership.
- Enforce pair uniqueness by presentation alone.

Do not add:

- Generalized repository.
- Dependency-injection framework.
- Generic charge protocol.
- Polymorphic owner.
- Invoice abstraction.
- Third-party dependency.

## Persistence Boundaries

Visit editor owns an in-memory WorkItem draft separate from last successful
SwiftData state.

Save Progress, completion, and correction each apply all metadata changes as
one explicit Visit persistence action:

- WorkItem insertion.
- WorkItem removal.
- Service replacement.
- Amount override.
- Outcome change.
- Work Notes change.

Failed save rolls back the action context without losing recoverable draft
state.

Photograph operations remain independently persisted through
`PhotographLibrary`. Cancelling Visit draft changes does not roll back a
completed Photograph operation.

Photo-aware in-progress Visit discard retains its existing file transaction.
The same Visit deletion cascades through VisitHorse to WorkItem metadata.
WorkItems require no new file operation, coordinator, or reconciliation path.

## V3-to-V4 Migration

The migration chain becomes:

```text
FarrierFlowSchemaV1
    → FarrierFlowSchemaV2
    → FarrierFlowSchemaV3
    → FarrierFlowSchemaV4
```

Add an explicit intended-lightweight V3-to-V4 stage while preserving prior
stages.

Migration requirements:

- Preserve production store identity, configuration name, URL, and location.
- Preserve every V1, V2, and V3 record and relationship.
- Preserve Photograph metadata and external canonical files.
- Add `Visit.workItemPolicyVersion` with a migration-safe default of `0`.
- Assign `workItemPolicyVersion == 0` to every existing Visit.
- Add empty Service and WorkItem populations.
- Existing Horses receive nil default Service.
- Existing VisitHorses receive empty WorkItem collections.
- Fabricate no Service.
- Fabricate no WorkItem.
- Fabricate no name snapshot.
- Fabricate no amount.
- Fabricate no currency code.
- Fabricate no default relationship.
- Fabricate no unavailable placeholder.

Required migration coverage:

1. Direct V3-to-V4 migration with complete Visit, VisitHorse, Photograph, and
   file-backed Photograph state, proving every existing Visit receives policy
   `0`.
2. Chained V2-to-V3-to-V4 migration proving every existing Visit receives
   policy `0`.
3. Chained V1-to-V2-to-V3-to-V4 migration proving every existing Visit
   receives policy `0`.
4. Verification of every prior field, inverse, delete rule, and Photograph.
5. Verification that Horses have nil defaults.
6. Verification that VisitHorses have no WorkItems and migration fabricates no
   WorkItem data.
7. Validation and reopening of a migrated completed Serviced VisitHorse with no
   WorkItems under policy `0`.
8. Creation of valid policy-`1` V4 Services, defaults, and WorkItems after
   migration.
9. Release and reopening of the same V4 store with the policy value preserved.

The additive V3-to-V4 migration must be proven on iOS 18 before any other Slice
4 implementation work proceeds. The chained V1-to-V2-to-V3-to-V4 fixture must
be non-vacuous: it creates a Visit after reaching the first schema version that
supports Visits, then proves the Visit receives policy `0` when the same store
reaches V4. If executable migration tests show that the scalar default,
additive models, or optional relationships are unsafe, implementation stops
for schema review. Never recreate, replace, or silently empty the production
store.

## Validation Boundaries

### Editor boundary

Editors validate:

- Required normalized Service name.
- Exact `en-US` price grammar.
- Checked conversion to minor units.
- Active Service selection.
- Eligible Service selection after pair filtering.
- Nonnegative amount.
- Outcome-dependent WorkItem behavior.
- Checked draft totals.

### Domain boundary

Domain rules validate:

- Visit policy is exactly `0` or `1` and never changes after creation or
  migration.
- Service fields and `USD`.
- Archived Service has no Horse-default references.
- Every non-nil Horse default resolves an active Service with matching inverse.
- WorkItem has VisitHorse and Service.
- Both WorkItem inverses match.
- WorkItem service-name snapshot is normalized and nonempty.
- WorkItem amount is nonnegative.
- WorkItem currency is exactly `USD`.
- `(VisitHorse, Service)` pair is unique.
- Not Serviced owns no WorkItems.
- Completed policy-`0` Serviced owns zero or more valid WorkItems.
- Completed policy-`1` Serviced owns at least one valid WorkItem.
- Every checked subtotal and Visit total succeeds.
- Catalog edits do not mutate WorkItem snapshots.
- Existing V3 Visit, Photograph, and history invariants remain valid.

### Persistence boundary

Immediately before every controlled save, complete-graph validation fetches and
checks all relevant Services, Horses, Visits, VisitHorses, and WorkItems.

Start Visit, Save Progress, completion, correction, Service save, Service
archive, Service Reactivate, Service delete, and Horse-default save report
success only after validation and persistence succeed.

### Reopening boundary

Persistent reopening revalidates:

- Supported and preserved Visit policy.
- V4 ownership and inverses.
- Pair uniqueness.
- Service lifecycle constraints.
- WorkItem snapshots and currency.
- Outcome-dependent WorkItem counts.
- Checked totals.
- Deterministic ordering.

No invalid persisted duplicate or overflow receives success-shaped repair.

## Invalid and Unavailable Data

Controlled writes never create:

- Empty Service name.
- Negative Service default amount.
- Non-`USD` Service.
- Archived Service used as Horse default.
- WorkItem without VisitHorse.
- WorkItem without Service.
- Inverse mismatch.
- Empty WorkItem name snapshot.
- Negative WorkItem amount.
- Non-`USD` WorkItem.
- Duplicate `(VisitHorse, Service)` pair.
- Not Serviced VisitHorse with WorkItems.
- Completed policy-`1` Serviced VisitHorse without WorkItems.
- Unknown Visit WorkItem policy.
- Overflowing subtotal or Visit total.

When invalid persisted data is read:

- Raw values are not displayed as valid localized content.
- Duplicate WorkItems are not merged or deleted.
- Overflow is not wrapped or approximated.
- Unsafe actions are disabled.
- Existing readable snapshots may remain visible where safe.
- A localized unavailable state explains that records could not be verified.
- Underlying structural error is logged locally.

Production container or migration failure remains visible. There is no
in-memory success fallback or destructive store recreation.

## Accessibility, Localization, and Field Readiness

Use native controls and behavior on iOS 18 and iOS 26.

Requirements:

- Service and WorkItem rows announce name, amount, archive state, and
  selection state.
- Complimentary work is announced as Complimentary.
- Amount validation is visible and available to VoiceOver.
- Add Service announces unavailable and already-selected exclusions through
  clear state copy rather than color.
- Destructive WorkItem and Work Notes clearing confirmation names what will be
  lost.
- Dynamic Type may wrap prices and names without hiding actions.
- Primary targets remain at least 44 by 44 points.
- Semantic colors support Light Mode, Dark Mode, and Increased Contrast.
- Reduce Motion is respected.
- Common Add Service, amount edit, Save Progress, and Complete Visit actions
  remain usable with one hand.

FarrierFlow remains English-only for this release. User-facing strings stay in
the string catalog and formatting remains localization-ready.

Price parsing is deliberately `en-US`; currency display uses localized
Foundation USD formatting.

## Test and Verification Matrix

### Service catalog

- Name normalization.
- Empty-name rejection.
- Zero and positive default prices.
- Negative and overflow rejection.
- Explicit `USD` persistence.
- Rename and reprice affect future WorkItems only.
- Archive blocked by Horse defaults.
- Archive allowed with WorkItem history after defaults are cleared.
- Archived Service excluded from new selection.
- Reactivate restores future selection.
- Permanent delete allowed only when unreferenced.
- Deletion blocked by in-progress and completed WorkItems.

### USD parser

Acceptance coverage:

- `0`
- `12`
- `12.`
- `12.5`
- `12.50`
- `$12.50`
- `1,250.00`
- Valid surrounding whitespace
- Maximum exact amount that fits `Int64` cents

Rejection coverage:

- Empty and whitespace-only input.
- `$`
- Negative and positive signs.
- Parenthesized negatives.
- More than two fraction digits.
- Leading decimal without whole digits.
- Malformed grouping.
- Scientific notation.
- Currency-code text.
- Unsupported separators.
- Internal whitespace.
- Alphabetic text.
- Multiplication or addition overflow.

Tests prove no `Double` or `Float` path is used for conversion.

### WorkItem identity and uniqueness

- One default WorkItem per Horse default at Start Visit.
- Default Service excluded from Add Service.
- Manual duplicate blocked.
- Replacement duplicate blocked.
- Same Service allowed for different VisitHorses.
- Multiple distinct Services allowed for one VisitHorse.
- Save Progress rejects duplicate pair.
- Completion rejects duplicate pair.
- Correction rejects duplicate pair.
- Domain validator rejects duplicate pair.
- Reopening rejects duplicate pair without merging.

### Outcomes and correction

- Pending may retain WorkItems.
- In-progress Serviced may temporarily have none.
- Not Serviced with WorkItems fails under policy `0` and policy `1`.
- Policy-`0` completion permits a Serviced Horse with no WorkItems.
- Policy-`1` completion requires a WorkItem for every Serviced Horse.
- A policy-`0` Serviced Horse with no WorkItems has an unavailable subtotal and
  makes the complete Visit total unavailable.
- Confirmation cancellation preserves outcome, notes, WorkItems, and amounts.
- Confirmation acceptance clears WorkItems and Work Notes.
- Completed correction can add, remove, replace, and reprice.
- Archived existing WorkItem may be repriced or removed.
- Archived Service cannot be selected for new or replacement WorkItem.
- Legacy correction retains policy `0` and permits known WorkItems without
  requiring fabricated history.
- Slice 4 correction retains policy `1` and its WorkItem requirement.
- Unknown policy values fail closed.
- Correction preserves Visit, Photograph, membership, timestamp, and snapshot
  invariants.

### Checked totals

- Per-Horse subtotal.
- Visit total.
- Complimentary lines.
- Nonempty all-zero subtotal.
- Maximum non-overflowing total.
- WorkItem-add overflow.
- Amount-override overflow.
- Replacement overflow.
- Start Visit default-copy overflow.
- Save Progress overflow.
- Completion overflow.
- Correction overflow.
- Reopening overflow fails closed.

### Schema and relationships

- V4 registers exactly ten models.
- V1, V2, and V3 remain frozen.
- Visit has one immutable `workItemPolicyVersion` with supported values `0` and
  `1`.
- Every new inverse is registered.
- Delete rules match the approved matrix.
- Domain-required WorkItem relationships use deletion-safe storage.
- Horse default is optional.
- VisitHorse owns WorkItems.
- WorkItem deletes preserve Service and VisitHorse.
- Visit discard cascades WorkItems without affecting Services.

### Migration and reopening

- Direct V3-to-V4 migration assigns policy `0`.
- Chained V2-to-V3-to-V4 migration.
- Chained V1-to-V2-to-V3-to-V4 migration assigns policy `0`.
- No fabricated Services, defaults, WorkItems, snapshots, amounts, or currency.
- Migrated completed Serviced Visits with no WorkItems validate and reopen.
- Photograph metadata and files preserved.
- New Visits are explicitly created with policy `1`.
- New completed policy-`1` Serviced Visits without WorkItems fail validation.
- The policy value survives persistent-store reopening.
- V4 graph creation after migration.
- Relaunch with Horse defaults.
- Relaunch with in-progress WorkItems.
- Relaunch after completion.
- Relaunch after completed correction.
- Relaunch after Service rename, repricing, archive, and Reactivate.
- Deterministic ordering after reopening.

### UI acceptance flow

1. Create an active Service with a USD price.
2. Set it as a Horse default.
3. Schedule an Appointment containing that Horse.
4. Start Visit.
5. Verify one default WorkItem appears.
6. Verify the same Service is excluded from Add Service.
7. Add a different Service.
8. Remove, replace, and deliberately override WorkItems.
9. Verify invalid duplicate replacement is unavailable.
10. Verify zero amount displays as Complimentary.
11. Confirm and cancel Not Serviced cleanup behavior.
12. Complete Visit with every Serviced Horse holding valid WorkItems.
13. View WorkItems, Horse subtotals, and Visit total.
14. Open Visit through Horse History.
15. Rename and reprice catalog Service.
16. Verify completed name and amount snapshots remain unchanged.
17. Attempt archive while Service is a Horse default and verify it is blocked.
18. Clear or replace Horse defaults, then archive Service.
19. Verify archived Service remains readable through historical WorkItem.
20. Correct completed Visit while preserving every invariant.
21. Terminate and relaunch.
22. Verify complete V4 graph, pair uniqueness, snapshots, totals, ordering,
    Photographs, and relationships.

### Final implementation gates

After implementation and focused review:

1. Full iOS 18 unit and integration suite.
2. Full iOS 26 unit and integration suite.
3. Focused iOS 18 Services and WorkItem UI flow.
4. Full iOS 26 UI suite.
5. Direct and chained migration gates.
6. Persistent reopening gates.
7. iOS 18 build.
8. iOS 26 build.
9. `git diff --check`.

Run serially under the repository resource-constrained verification policy.

## Explicit Exclusions

Slice 4 does not add:

- Visit-owned WorkItems.
- Barn-call, travel, mileage, emergency, shared, or generic charges.
- Quantity.
- Duplicate Service WorkItems for one VisitHorse.
- Unit-price multiplication.
- Automatic duplicate merging.
- Taxes.
- Discounts.
- Tips.
- Deposits.
- Refunds.
- Adjustments.
- Multi-currency UI.
- Exchange rates.
- Currency conversion.
- Invoices.
- PDFs.
- Invoice numbering.
- Invoice relationships.
- Invoice locks.
- Payment status.
- Payment processing.
- Customer-facing estimates or quotes.
- Inventory or material tracking.
- Automatic next appointments.
- Export.
- Subscriptions.
- Accounts.
- Networking.
- CloudKit.
- Synchronization.
- App-managed backup.
- Notifications.
- Generalized Settings.
- Custom navigation, custom tabs, or manually simulated Liquid Glass.
- Speculative invoice or generic-charge abstractions.
- A generalized Visit-policy framework or policy model.

## Specification Authorization

The user approved the complete Slice 4 design and required the final
corrections captured here:

1. Enforce one WorkItem per Service per VisitHorse.
2. Define exact `en-US` USD entry parsing with checked integer minor-unit
   persistence.
3. Preserve pre-Slice-4 Visit history through immutable
   `workItemPolicyVersion` values `0` and `1`, without fabricating WorkItems.

This specification authorizes design documentation only. It does not authorize
an implementation plan, schema implementation, migration implementation,
Swift source changes, UI implementation, builds, or tests.
