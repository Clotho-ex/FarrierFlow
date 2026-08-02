# Slice 5A — Owner Setup and Run Sheet Hub Design

**Status:** Implemented

**Date:** 2026-08-02

## Purpose

Slice 5A changes FarrierFlow from a set of blank record screens into an
owner-operated field hub. The farrier records reusable business information and
operating defaults once, then reaches customer and work records through the
next valid action instead of repeatedly navigating administrative forms.

The app remains for the independent farrier. It does not add a customer-facing
mode, accounts, networking, or shared access.

## Product Boundary

- Preserve the complete workflow: Appointment, Horse History, work performed,
  hoof photographs, Invoice, payment status, and later next-appointment work.
- Keep Today, Schedule, and Clients as the only tabs.
- Keep Client, Horse, Service Location, Appointment, Visit, WorkItem,
  Photograph, and Invoice information explicit and record-specific.
- Reuse only owner-level facts: business identity/contact information,
  optional Appointment-duration default, optional Invoice-due default, default
  Invoice note, and the Service catalog.
- Keep Horse default Service and appointment interval on Horse because they are
  Horse-specific, not global owner preferences.
- Keep Service Location and Horse selection explicit on every Appointment.
- Add no automatic next Appointment, notification, payment processing,
  customer portal, account, or synchronization behavior.

## Behavioral Design Principles

The requested cognitive principles apply only to truthful product state.

### Decision Fatigue

- Ask one setup decision per screen.
- Require only business or farrier name before exposing the operational hub.
- Keep contact details and operating defaults optional.
- Rank one next action on Today; preserve alternate routes in native navigation.
- Use progressive disclosure for notes and overrides.

### Goal Gradient

- Show Visit progress using the actual resolved-Horse count.
- Show workflow state only when backed by Appointment, Visit, WorkItem,
  InvoiceLineItem, and Invoice status data.

### Reciprocity

- After the minimum identity step, immediately provide a personalized hub,
  organized work, and contextual recovery actions.
- Never require a complete business questionnaire before showing product value.

### Endowment Effect

- Use the saved business name in the hub and Invoice preview context.
- Present Services and defaults as the farrier's reusable setup.
- Reflect saved configuration immediately after each successful step.

### Loss Aversion

- Warn only about real unsaved draft changes, discarded setup edits, or a real
  incomplete prerequisite that blocks work.
- Never fabricate expiring rewards, streaks, missed opportunities, or urgency.

### Contrast Effect

- Show a saved default beside an explicit override when that comparison helps
  the user verify a draft.
- Show selected Invoice work and checked total before immutable generation.
- Never use decoy pricing, crossed-out invented values, or manipulative cost
  framing.

### Smart Defaults

- Prefill new Appointment duration from the BusinessProfile when present.
- Prefill new Invoice due date from the saved due-day interval; begin the owner
  preference at the existing 14-day product default.
- Continue prefilling Invoice note from BusinessProfile and Visit WorkItems from
  Horse default Service.
- Apply each default once at draft creation. User edits are authoritative.

## Owner Setup Flow

Owner setup is one native form presented before Today. It asks only for the
minimum identity needed to personalize the app and create future Invoices.

### First Run — Identity

- Open directly on the identity form without an introductory screen or setup
  checklist.
- Require one normalized business or farrier name.
- Explain that the name appears on Today and future Invoices.
- Save successfully, then open Today immediately.
- Keep phone, email, address, operating defaults, Services, and Service
  Locations out of first run.

### Contextual Setup After Activation

- My Business owns optional contact information, Appointment duration, Invoice
  due days, and default Invoice note after activation.
- Services remain in the Service catalog and surface when recorded work needs
  them.
- Service Locations remain in their feature and surface when scheduling needs
  one.
- Client and Horse creation ask only for fields required by the active task;
  optional notes and contact details remain secondary.
- No contextual setup step replays first-run onboarding.

### Completion and Resumption

- Do not persist a parallel onboarding-complete Boolean or version.
- Identity readiness derives from one valid BusinessProfile.
- First-customer readiness derives from existing Client records; it is not an
  onboarding completion flag or a required owner-setup step.
- Optional defaults never block readiness.
- Before identity exists, relaunch resumes the name field. After identity
  exists, relaunch opens Today.
- Existing users with a valid identity bypass forced onboarding and see Today.
- If an active Service or all Barns later disappear, do not replay welcome;
  Today displays the specific missing prerequisite and recovery action.

## Owner Default Data Contract

BusinessProfile adds:

| Field | Meaning |
| --- | --- |
| `defaultAppointmentDurationMinutes: Int?` | Positive owner default; `nil` means Ask Every Time |
| `defaultInvoiceDueDays: Int?` | Positive owner default; begins at 14; `nil` means No Due Date |

Both fields are reusable preferences only. They do not relate BusinessProfile
to Appointments or Invoices.

### Appointment Application

- A new Appointment draft reads the current profile duration once.
- Editing an existing Appointment uses its persisted duration and ignores the
  current profile default.
- A prefilled value is visible, editable, and clearable before save.
- Changing BusinessProfile never rewrites an Appointment or open draft.

### Invoice Application

- A new Invoice draft reads due days and default note once.
- Due Date derives from Invoice Date with the injected Calendar.
- If Invoice Date changes before generation, a due date that still equals the
  previously derived default moves by the same rule. A user-overridden or
  cleared due date stays authoritative.
- Changing BusinessProfile never rewrites a generated Invoice, PDF, snapshot,
  or already-open draft.

## Today Run Sheet Hub

Today remains the default tab and one native navigation stack. It is an
operational ledger, not a metrics dashboard.

### First Viewport

1. Saved business name and localized current date establish ownership and
   context.
2. One edge-to-edge Run Sheet action field presents the highest-priority valid
   current-day Appointment or active Visit with enough context to act safely.
3. Remaining chronological appointments continue below on a vertical workline;
   the promoted record is not duplicated immediately below the action field.
4. Setup or billing attention appears only when it has a direct recovery route.

No fabricated greeting, metric, photograph, revenue total, trend, or sample
appointment appears.

### Approved Run Sheet Composition

The approved composition combines **Next Stop Band** and **Active Work**.

- Scheduled Appointment: the Survey Ink action field shows Next Stop, scheduled
  time, Service Location, its address when saved, Horses, explicit Scheduled state, and Open
  Appointment.
- In-progress Visit: the same field shows Next Action, explicit Visit In
  Progress state, Service Location, Horses, actual resolved-Horse count, native
  progress semantics, and Resume Visit.
- The field changes content from persisted state; it does not become navigation,
  a carousel, a custom tab, or a separate dashboard.
- Setup, invoicing, payment-status, and general scheduling actions use a flat
  native action section rather than implying that a current-day stop exists.
- Later Appointments and lower-ranked attention remain concise native rows below
  the field.

Generated compositions are structural north stars, not screenshots to trace.
Implementation must not copy fixed heights, synthetic record values, oversized
type that breaks Dynamic Type, or non-native chrome from the images.

### Deterministic Next-Action Ranking

Rank the first valid candidate:

1. Resume an in-progress Visit.
2. Open the next current-day Appointment whose Visit has not started.
3. Add the first Client.
4. Create an Invoice for completed, uninvoiced work, grouped by eligible Client.
5. Review an Unpaid Invoice requiring manual payment-status action.
6. Schedule an Appointment.

Candidates within one rank order by relevant date ascending, then stable
persistent identity. Today never infers urgency from wall-clock lateness because
cancellation, no-show, and time-based Appointment resolution remain deferred.

### Workline States

An Appointment's visible progress may include only states the graph proves:

- Scheduled: no Visit.
- In Progress: Visit exists without `completedAt`.
- Work Complete: completed Visit has eligible uninvoiced WorkItems.
- Invoiced: every relevant Client-owned WorkItem is linked to an InvoiceLineItem.
- Paid: linked Invoice status is Paid.

Mixed-client Visits may have different invoicing states per Client. The hub
must not collapse them into a false whole-Visit billing state.

### Empty and Partial States

- No BusinessProfile: resume Identity setup.
- Missing active Service: the Visit work editor explains why recorded work
  needs one and offers Create Service at that moment.
- Missing Service Location: the Appointment editor explains why scheduling
  needs one and offers Add Service Location without discarding the draft.
- No Client: add the first Client directly from Today. If appointment creation
  reaches a horse editor first, allow Client creation there without losing the
  appointment or horse draft.
- No Appointment today: offer Schedule Appointment and show no fake activity.
- Completed work not ready for invoicing: name the real missing prerequisite.
- No attention and no Appointment: let the quiet state remain quiet.

## Field Book and Run Sheet Visual Contract

- Use the approved `DESIGN.md` seed and Operate mode.
- Keep system typography; use monospaced digits only for times, money, invoice
  numbers, and progress counts.
- Use semantic platform surfaces plus restrained Survey Ink accent.
- Reserve the large Survey Ink field for a promoted current-day Appointment or
  active Visit. Do not turn setup, billing, or empty states into equally loud
  banners.
- Use a leading rule or native progress treatment as a workline; never make it
  a custom tab bar or gesture control.
- Use native depth and avoid custom shadows, gradients, paper textures, glass
  cards, nested cards, and decorative icon containers.
- Keep one primary action visually dominant. Alternate actions use native
  secondary placements.
- Respect Reduce Motion; animate only state transition, insertion, removal, or
  completion and keep content visible without animation.

## Navigation and Ownership

- `RootView` decides between identity setup and the three-tab app from persisted
  BusinessProfile truth.
- Onboarding owns identity gating, not BusinessProfile, Services, or Barns
  domain validation.
- Today owns summary projection and action ranking.
- Schedule continues owning Appointment creation and detail.
- BusinessProfile, Services, Barns, Visits, and Invoices continue owning their
  editors and persistence boundaries.
- Routes carry persistent identifiers or small immutable values. Today does not
  retain another feature's observable model.
- Business Profile remains reachable from Clients > More for later edits. No
  generalized Settings destination is added.

## Persistence and Failure Behavior

- SwiftData remains local source of truth.
- Add no onboarding-progress model or completion flag.
- Save each setup record through its established validated persistence boundary.
- A failed save keeps entered data visible and does not mark a step complete.
- A failed Today projection shows a native unavailable state and retry; it does
  not replace facts with empty success-shaped content.
- FarrierFlow remains unshipped. Implementation revises the first-shipping V1
  BusinessProfile contract without silently deleting an incompatible local
  development store. Container failure remains visible.

## Accessibility and Field Readiness

- The identity field and Continue action expose clear VoiceOver labels, hints,
  required state, and disabled state without relying on color.
- The Run Sheet action field announces action, state, record, time when
  applicable, Service Location, Horses, and Visit progress in a concise order.
- Visit progress exposes resolved and total Horse counts as an accessibility
  value; color and bar length are supplementary.
- Workline markers use text or accessibility values in addition to color and
  shape.
- Dynamic Type may stack all metadata and actions vertically without clipping;
  the action field grows with content and has no fixed height.
- Frequent actions remain at least 44 by 44 points and reachable with one hand.
- Light Mode, Dark Mode, Increased Contrast, Reduce Motion, and VoiceOver are
  first-class acceptance states on iOS 18 and iOS 26.

## Testing Contract

Focused implementation coverage must prove:

- Missing, valid, and failed owner-identity states.
- Setup resumption after process termination and persistent-store reopening.
- Existing-user onboarding bypass.
- Positive or nil owner-default validation.
- Appointment and Invoice default application, clearing, override, and
  non-retroactivity.
- Invoice Date changes preserve explicit due-date overrides.
- Deterministic Today ranking and tie-breaking.
- Scheduled and active-Visit Run Sheet content, action routing, progress values,
  and promoted-record deduplication.
- Mixed-client invoicing state remains Client-specific.
- Empty and missing-prerequisite recovery routes.
- VoiceOver labels/values and accessibility Dynamic Type composition.
- No iOS 26-only essential behavior; iOS 18 fallback parity.

The approved implementation plan must name focused serial test commands and one
simulator destination per gate under the repository's resource policy.

## Explicit Exclusions

- Customer-facing mode, authentication, accounts, networking, or shared access.
- Automatic next Appointment or any Slice 7 implementation.
- Payment processing, reminders, notifications, export, subscription, or
  backup.
- Generalized Settings, custom navigation, custom tab bar, or global create
  flow.
- Default Client, Horse, Service Location, or Horse Service.
- Fabricated Services, prices, customers, appointments, photographs, revenue,
  rewards, scarcity, urgency, or progress.
- Western, rustic, veterinary, cartoon, horseshoe, parchment, or ornamental
  horse styling.
- Per-change autosave or silent success fallback.
