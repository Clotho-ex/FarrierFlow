# FarrierFlow Roadmap

## Delivery Principle

FarrierFlow is delivered as complete vertical slices. Each slice must produce a
coherent user outcome, preserve the approved data contract, build successfully,
pass relevant tests, and work after relaunch before the next slice begins.

Later capabilities remain high-level until their product decisions, data
ownership, and migration behavior are shaped. They must not influence the
current schema or interface.

FarrierFlow has not shipped. Slice 5 supersedes the historical pre-release
schema stages described in Slices 1 through 3 with one complete first-shipping
`FarrierFlowSchemaV1`; the app implements no migration from those pre-release
stores.

## Active Release — FarrierFlow 1.0 Revenue Launch

**Status:** Units 1–6 are integrated with the current owner workflow on local
`main`. Unit 7 — Release Candidate, TestFlight, and Submission is active, and
the integrated local candidate passed its complete serial Simulator
verification matrix on 2026-08-19. The final six-shot 6.3-inch screenshot set
was captured locally on 2026-08-20. The release is not complete and remains
blocked on the remaining commercial, screenshot-upload, physical-device,
signed archive, TestFlight, and submission gates.

### Outcome

Ship the completed core farrier workflow as a free App Store download with a
monthly or yearly FarrierFlow Pro subscription, begin earning revenue, and
avoid delaying 1.0 for Export, backup, speculative hardening, or additional
features.

### Commercial Scope

- One auto-renewable subscription group: **FarrierFlow Pro**.
- Monthly product
  `com.farrierflow.yusufcan.FarrierFlow.pro.monthly` at a US launch price of
  $14.99 per month.
- Yearly product
  `com.farrierflow.yusufcan.FarrierFlow.pro.yearly` at a US launch price of
  $119.99 per year.
- One 14-day introductory free trial under Apple's subscription-group
  eligibility rules.
- Full access for verified active, trial, canceled-but-paid-through, and
  billing-grace entitlements.
- Permanent read-only access when no current entitlement exists. Existing
  records, photographs, history, and PDF generation/sharing from existing
  Invoice snapshots remain available; every ordinary business-record mutation
  is unavailable.
- Native Restore Purchases and Manage Subscription behavior.
- No FarrierFlow account, server, cloud synchronization, or persisted
  entitlement state.

### Release Scope

- Start from `origin/main`; keep the unfinished Slice 8 Unit 2 branch preserved
  and unmerged.
- Port the confirmed stale-Horse Appointment-save fix independently so a failed
  new Appointment creates no partial record and a corrected retry can succeed.
- Add one feature-owned StoreKit entitlement and subscription surface without a
  generalized Settings architecture.
- Gate normal production mutation controls while preserving all read-only
  navigation and existing Invoice PDF sharing.
- Supply the production App Icon, privacy manifest, public Privacy Policy and
  Support pages, truthful App Store metadata/screenshots, StoreKit products,
  Paid Apps Agreement, tax, banking, TestFlight, and submission configuration.

### Release Blockers Only

- Crash, data loss, corrupted or materially false business records, broken
  Appointment-to-next-Appointment workflow, unusable Invoice output, incorrect
  subscription access, privacy-disclosure failure, or App Review/submission
  failure.
- On 2026-08-19, the integrated local `main` candidate rooted at `463b81a`
  passed the complete serial automated matrix: iOS 18 and iOS 26
  unit/integration suites each passed 412 tests; the focused iOS 18
  subscription and first-customer gate passed 6 tests; the expanded full iOS
  26 UI gate passed 30 tests; both persistent-reopen gates passed 16 tests; and
  both Simulator builds succeeded. Source and built privacy manifests,
  string-catalog compilation, StoreKit configuration/product contracts,
  version/build/deployment metadata, compiled Default/Dark/tintable App Icon
  renditions, and `git diff --check` passed. The only correction was a
  test-only, condition-based retry for ignored iOS 18 Today navigation taps;
  production behavior did not change. A separately authorized signed archive
  and Organizer validation remain required.
- The separate website publishes public Privacy Policy and Support pages at
  `https://farrierflow.vercel.app/privacy/` and
  `https://farrierflow.vercel.app/support/`. Both returned HTTP 200 without
  authentication on 2026-08-15, and both verified URLs were entered in App
  Store Connect on 2026-08-18.
- On 2026-08-18, App Store Connect saved the prepared subtitle, promotional
  text, description, keywords, Support URL, Business category, review notes,
  account-free sign-in setting, and 4+ age rating; published App Privacy as
  **Data Not Collected**; configured a free United States launch matching both
  subscriptions; and disabled Mac and Vision Pro availability for the
  iPhone-only 1.0 scope. Both monthly and yearly product review screenshots
  were uploaded and both products were added to the version 1.0 draft, where
  they reported **Ready for Review**. Copyright, exact review contact, Content
  Rights and final release-behavior confirmation remain incomplete. The final
  six-shot 1206 x 2622 RGB screenshot set was captured and visually accepted
  from the integrated candidate on 2026-08-20, but App Store Connect upload
  remains pending; the last live check showed zero version 1.0 screenshots
  after Chrome file-chooser access blocked the upload.
- TestFlight still had no build on 2026-08-15, so project build 1 remained the
  first available upload candidate. The Paid Apps Agreement, bank account,
  both submitted U.S. tax forms, and updated Apple Developer Program License
  Agreement were confirmed active or accepted on 2026-08-18. App Store
  Connect's stale agreement-review banner still requires a propagation recheck
  before upload or submission.
- Final product-page screenshot upload and metadata, physical-device
  acceptance, signed archive, TestFlight, and submission gates remain unmet.

Low-risk edge-case hardening, feature expansion, and aesthetic polish do not
block 1.0 once the real owner flow and major failure, relaunch, offline,
subscription, and cancellation paths work reliably.

### Exit Criteria

- A new customer can download the app, start either 14-day trial, complete
  owner setup, and finish the full core workflow through next Appointment.
- The same flow works offline after entitlement and data are established.
- Billing grace retains full access. Expiration, billing retry outside grace,
  revocation, or no purchase produces read-only access without deleting,
  hiding, or changing source data.
- PDFs remain generatable and shareable from existing Invoice snapshots in
  read-only mode.
- Restore or renewal returns full access without data migration or relaunch.
- StoreKit sandbox, focused iOS 18 compatibility, complete iOS 26 release
  verification, physical-device TestFlight, privacy, accessibility, metadata,
  and App Store submission gates pass.

The approved contract is recorded in
`docs/superpowers/specs/2026-08-10-v1-revenue-release-design.md`.

## Slice 0 — Foundation

**Status:** Complete.

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

**Status:** Complete.

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
- At Slice 1 completion, Add Existing Horse listed only horses with no
  appointment memberships that were not already assigned to the destination
  location. Slice 2 replaces this with the Visit-aware relocation rule.
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
- At Slice 1 completion, Horse relocation was blocked while any appointment
  referenced it. Slice 2 replaces this with the Visit-aware relocation rule.
  A blocked relocation keeps the existing location and presents a native alert.
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
- At Slice 1 completion, past Appointment and Visit history were deferred.
  Slice 2 adds completed Visit history only from Horse Detail; a general past
  Appointment destination remains deferred.
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
- Slice 1 relocation tests prove its then-current any-membership rule. Slice 2
  replaces that coverage with Visit-aware blocking while continuing to prove
  that failed relocation preserves the Horse and leaves every Appointment and
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

## Slice 2 — Visit Completion

**Status:** Complete.

### Outcome

Start work from an existing Appointment, record an outcome for every scheduled
Horse, complete the Visit, view it from Horse History, and prove the complete
historical graph survives process termination and store reopening.

### Scope

#### Visit graph

- Add separate Visit and VisitHorse models in a complete V2 SwiftData schema.
- One Appointment has zero or one Visit.
- Start Visit atomically captures actual `startedAt`, the Appointment and Barn
  relationships, immutable service-location name and optional address
  snapshots, and one pending VisitHorse per AppointmentHorse.
- Visit state derives from optional `completedAt`; no redundant Visit status is
  persisted.
- VisitHorse outcome is Pending, Serviced, or Not Serviced.
- Work Notes are optional only for serviced Horses.
- Unscheduled Horses cannot be added.

#### Progress and completion

- Save Progress persists valid pending or resolved outcomes and keeps the Visit
  in progress.
- Complete Visit requires every outcome resolved, at least one serviced Horse,
  exact Appointment-to-Visit membership, valid relationships, and valid Work
  Notes.
- Completion saves the draft and immutable `completedAt` atomically.
- Dirty drafts require dismissal confirmation.
- Backgrounding makes a best-effort Save Progress attempt only.
- Process termination loses unsaved draft and in-memory error state; relaunch
  restores the last successful save.
- An in-progress Visit may be discarded with confirmation, cascading only its
  VisitHorse records.
- A completed Visit may be corrected without changing relationships,
  timestamps, snapshots, membership, or completed state.
- Completed Visits cannot be deleted.

#### Appointment and deletion rules

- Appointment Detail offers Start Visit, Resume Visit, or View Visit according
  to Visit state.
- Once a Visit exists, Appointment Barn and horse membership are read-only.
- Scheduled start, Appointment Notes, and expected duration remain editable but
  cannot invalidate or alter the Visit.
- Appointment deletion is blocked while any Visit exists.
- Barn deletion is blocked while any Visit references it.
- Horse deletion is blocked while VisitHorse references it.

#### Relocation and history

- Appointment with no Visit blocks Horse relocation regardless of date.
- Appointment with an in-progress Visit blocks Horse relocation.
- Appointment with a completed Visit does not block Horse relocation.
- Missing or invalid relationships fail closed.
- Relocation never rewrites Appointment or Visit history.
- Horse Detail adds completed Visit history with no new tab.
- Visit Detail and Horse History display immutable location snapshots.
- The current Barn record is navigable only while its optional stored reference
  resolves.
- Horse History orders by Visit start descending, completion descending,
  service-location name ascending, and Horse name ascending without adding a
  persisted ordering identifier.

#### Migration

- Preserve `FarrierFlowSchemaV1` as the prior five-model snapshot.
- Add the complete seven-model `FarrierFlowSchemaV2`.
- Use an explicit lightweight V1-to-V2 migration stage.
- Preserve the production store identity and every existing V1 record and
  relationship.
- Fabricate no Visit, VisitHorse, or snapshot for existing Appointments.
- Stop and return for schema review if the additive migration is not safe on
  iOS 18; never recreate or replace the production store.

### Exact Acceptance Flow

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

### Exit Criteria

- V1-to-V2 migration preserves the complete connected-record graph on iOS 18
  and iOS 26 without fabricating Visit data.
- Start, Save Progress, completion, correction, discard, deletion, and
  relocation rules pass unit and SwiftData integration tests.
- In-progress, completed, corrected, discarded, and post-relocation graphs pass
  persistent-store reopening tests.
- The exact UI acceptance flow passes on iOS 26 with focused iOS 18
  compatibility coverage.
- VoiceOver, Dynamic Type, Light Mode, Dark Mode, Increased Contrast, Reduce
  Motion, dirty-state confirmation, and localized Visit status are verified.
- Full unit and integration suites pass on iOS 18 and iOS 26.
- Both platform builds report zero project diagnostics.
- No deferred model, screen, dependency, service, or visual effect is
  introduced.

## Slice 3 — Hoof Photographs

**Status:** Complete.

### Outcome

Capture or import hoof photographs for any scheduled Horse, keep them attached
to the same VisitHorse across outcome changes, and preserve the combined
SwiftData-and-file record across relaunch and crash recovery.

### Scope

- Add Photograph and `VisitHorse.photographs` in the complete V3 schema.
- Migrate V2 to V3 lightly while preserving the chained V1-to-V2-to-V3 path.
- Support camera capture and the permission-scoped system photo picker.
- Normalize one upright, metadata-free, opaque sRGB JPEG with a maximum
  2,560-pixel longest edge and JPEG quality 0.82; retain no source or thumbnail.
- Store canonical files at
  `Application Support/HoofPhotographs/<photograph-uuid>.jpg`.
- Limit each VisitHorse to 16 available photographs without silently removing
  an existing record.
- Serialize add, delete, photo-aware Visit discard, and reconciliation through
  one feature-owned coordination boundary.
- Use temporary and quarantine files for rollback-safe mutations and
  filesystem-based, idempotent crash recovery.
- Preserve missing-file metadata as an explicit unavailable Photograph that
  the user may delete.
- Apply complete file protection and retain standard device-backup eligibility.
- Provide photograph management from in-progress Visit editing, completed Visit
  detail and correction, and Horse History through Visit Detail.

The complete durability, reconciliation, image-processing, privacy, and testing
contract is recorded in
`docs/superpowers/specs/2026-07-28-slice-3-hoof-photographs-design.md`.

## Slice 4 — Services and Pricing

**Status:** Complete.

### Outcome

Maintain an active Service catalog, record priced WorkItems per serviced Horse,
and preserve service and price snapshots in Visit history.

Money uses integer minor units and explicit USD currency codes. A Horse may use
one active default Service, and Visit completion requires recorded work for each
serviced Horse.

## Slice 5 — Invoicing

**Status:** Complete.

### Outcome

Create one Client invoice from selected completed Visits, preserve immutable
business, Client, Visit, Horse, Service, date, and price snapshots, track Unpaid
or Paid status, and share a native multi-page US Letter PDF entirely offline.

Mixed-client Visits are independently eligible per represented Client. Each
source WorkItem can appear on at most one InvoiceLineItem. Unpaid deletion
releases only those billing links; any remaining invoice reference keeps Visit
correction locked, and Paid history is permanent.

The complete contract and implementation sequence are recorded in:

- `docs/superpowers/specs/2026-07-30-slice-5-invoicing-design.md`
- `docs/superpowers/plans/2026-07-30-slice-5-invoicing.md`

## Slice 5A — Owner Setup and Run Sheet Hub

**Status:** Complete. Focused unit, persistent-reopening, first-run identity,
and complete first-customer UI verification passed.

### Outcome

Set up reusable owner information once, then open an action-led Today hub that
shows the farrier's next truthful step across setup, scheduled work, Visit
progress, invoicing, and payment status without adding a tab or customer-facing
mode.

### Scope

- Add a resumable first-run owner setup flow containing only the required
  Business Profile name. Saving it opens Today directly.
- Keep contact information, optional operating defaults, reusable Services,
  and Service Locations in My Business or their contextual feature flows;
  never present them as a first-run questionnaire or setup checklist.
- Add optional BusinessProfile defaults for new Appointment duration and new
  Invoice due days. Keep the existing default invoice note and Service catalog.
- Apply defaults once when a new draft is created. Keep every prefilled value
  visible and editable; never rewrite existing records when defaults change.
- Replace Today's passive empty/list presentation with a personalized Run
  Sheet hub: saved business identity, date, one state-adaptive ranked action,
  remaining chronological appointments, and truthful setup or billing
  attention.
- Make the first operating loop continuous: Today can add the first Client,
  Horse creation can add a missing Client without losing draft state, scheduled
  stops expose saved arrival context, and completing a Visit returns to Today's
  invoice-ready action.
- Preserve native Today, Schedule, and Clients tabs, independent navigation
  stacks, standard controls, local-first behavior, and the established data
  graph.
- Adopt the approved Field Book visual direction in `DESIGN.md`, including the
  restrained Survey Ink palette, Run Sheet action field, vertical workline,
  flat native depth, and outdoor/accessibility rules.

### Exclusions

- No customer account, customer-facing mode, networking, synchronization, or
  new user/account model.
- No automatic next appointment, notification, payment processing, export,
  subscription, generalized Settings destination, or new tab.
- No global default Client, Horse, Service Location, or Horse Service.
- No fabricated sample Services, prices, customers, appointments, photographs,
  rewards, urgency, or progress.
- No custom navigation, custom tab bar, simulated Liquid Glass, generic card
  dashboard, or western/rustic visual theme.

### Exit Criteria

- New and interrupted users resume the single required identity field from
  persisted truth; existing users with valid identity reach the hub without
  being forced through onboarding.
- Owner defaults prefill only new drafts, remain editable, and survive relaunch.
- Today selects one deterministic next action and preserves access to every
  current Appointment.
- Scheduled and active-Visit Run Sheet states show the correct action and real
  Visit progress without duplicating the promoted record below.
- Empty, active-work, uninvoiced-work, and unpaid-Invoice states each provide
  one relevant continuation action. Missing Service Locations recover while
  scheduling; missing Services recover while recording Visit work.
- A fresh owner can complete Client → Horse → Appointment without abandoning an
  open form, and Resume Visit always returns to editable in-progress work.
- VoiceOver, Dynamic Type, Light Mode, Dark Mode, Increased Contrast, Reduce
  Motion, iOS 18, iOS 26, and persistent reopening gates pass.
- The app contains no deferred capability or invented operational data.

The complete product and architecture contract is recorded in
`docs/superpowers/specs/2026-08-02-slice-5a-owner-setup-field-book-design.md`.

## Later Slices

Slice numbering records the capability sequence, not a required implementation
order. Slice 7 is complete. The 1.0 Revenue Launch temporarily supersedes the
numbered capability order. Export is paused, StoreKit is part of the approved
release, and every other later slice still requires explicit implementation
approval.

### Slice 6 — Payment Processing

Unpaid/Paid status and payment date shipped in Slice 5. Any future payment
collection or processing requires a separate product, privacy, failure, and App
Store decision and remains deferred. It is not the active implementation
candidate.

### Slice 7 — Next Appointment Assistance

**Status:** Complete. Units 1 through 6 are implemented and verified.

After successful Visit completion, offer a dismissible assistant that uses each
Horse's interval to prepare one editable Appointment draft. Preselect eligible
Serviced Horses, show every individual suggested date, use the earliest date at
the source Appointment's local time, and protect against already-scheduled or
superseded work. Keep the same action recoverable from completed Visit detail
through Horse History.

The farrier must review and save the normal Appointment. Add no automatic
creation, recurring series, reminder queue, Today ranking change, model, or
migration.

Closure verifies the complete three-Horse flow, Not Now without persistence,
Horse History recovery, selection-driven date recalculation, manual override
retention, ordinary subset save, Appointment detail, store reopening, and fresh
partial-duplicate projection. VoiceOver with accessibility Dynamic Type, iOS
18 and iOS 26 tests, persistent reopening, and both platform builds pass.

The approved implementation contract is recorded in
`docs/superpowers/specs/2026-08-03-slice-7-next-appointment-assistance-design.md`.

### Slice 8 — Export

**Status:** Paused for the 1.0 Revenue Launch. Unit 1 is present on `main`; Unit
2 and its supporting coordination commits remain preserved on
`codex/slice-8-unit-2-export-snapshot`. Do not merge or continue the remaining
units before launch without a new explicit priority decision.

Define user-controlled business-record and media export with explicit privacy,
format, and failure behavior. The approved design remains authoritative when
work resumes.

### Slice 9 — StoreKit Subscription

**Status:** Product design approved as part of the 1.0 Revenue Launch;
implementation plan awaiting review.

Introduce StoreKit 2 with the exact products, trial, read-only fallback,
restore, grace-period, offline, privacy, and App Store requirements defined by
the active release contract. It adds no SwiftData schema or FarrierFlow account.

### Slice 10 — Optional Backup

Evaluate an opt-in backup or synchronization design only after privacy,
conflict, account, recovery, migration, and operational requirements are
defined. CloudKit is not assumed.

## Deferred Capabilities

- Taxes, discounts, partial payments, payment processing, overdue automation,
  Draft or Sent states, recurring invoices, monthly statements, multi-client
  invoices, custom numbering, logos, themes, accounting integrations, and
  third-party PDF dependencies.
- Automatic next-appointment creation.
- Export.
- Subscription enhancements beyond the approved 1.0 monthly/yearly products,
  including weekly, lifetime, team, metered, promotional, offer-code, win-back,
  or server-managed access.
- Networking, accounts, integrations, CloudKit, synchronization, and backup.
- Notifications.
- Archive or generalized soft deletion.
- Custom navigation, custom tab bars, or custom iOS 26 visual effects.
- A generalized Settings destination beyond Business Profile and approved owner
  defaults.
- Cancellation, no-show, rescheduling, and time-based Appointment resolution.
- Completed Visit deletion and historical-date correction.
- Background tasks, external Visit draft files, and per-change autosave.

Later slice work must not add fields, routes, empty screens, services, or
abstractions for deferred capabilities before their scope is shaped and
explicitly approved.
