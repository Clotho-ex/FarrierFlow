# FarrierFlow Design Direction

## Purpose

FarrierFlow is a native, iPhone-first field tool for independent farriers in
the United States. The interface should feel durable, calm, professional,
efficient, and specific to farrier work. It should help a farrier act quickly
while standing at a barn, often outdoors and with one hand available.

The completed workflow through Slice 5 covers clients, independent service
locations, horses, appointments, Visit completion, Horse History,
VisitHorse-owned hoof photographs, priced recorded Services, invoices, native
PDF sharing, and payment status without introducing a new tab. It does not
visually imply later capabilities such as payment processing, statements,
accounting integrations, subscriptions, or synchronization.

## Platform Character

Use standard SwiftUI controls and system behavior:

- `TabView` for the three primary destinations: Today, Schedule, and Clients.
- One `NavigationStack` inside each tab.
- `List` for collections and record summaries.
- `Form`, `Section`, `TextField`, `Picker`, and `DatePicker` for data entry.
- Standard toolbars, menus, sheets, alerts, and confirmation dialogs.
- `ContentUnavailableView` for empty and unavailable states.

The app does not manually reproduce Liquid Glass. Native controls should inherit
the current system appearance on iOS 26 while remaining fully native on iOS 18.
iOS 26-only presentation refinements may be added later behind availability
checks, but they must not change the information architecture or make an
essential action unavailable on iOS 18.

## Visual Language

System typography, semantic colors, standard list styling, and platform spacing
provide the foundation. A restrained accent color may identify interactive
elements and selection, but color is never the only carrier of meaning.

Distinction should come from:

- Field-specific labels and concise action copy.
- Strong information hierarchy.
- Consistent spacing and alignment.
- Useful VisitHorse-specific hoof photography inside the Visit workflow.
- Clear empty states that explain the next valid action.
- Subtle success and warning haptics where they confirm a meaningful result.

Photographs appear only when the user opens a scheduled horse from an
in-progress or completed Visit. Other records reserve no empty photo frames or
decorative image treatments.

## Navigation

The app opens on Today and uses three native tabs:

1. Today
2. Schedule
3. Clients

Today and Schedule expose an appointment-creation action. Clients exposes a
client-creation action and a toolbar menu containing Service Locations,
Services, Invoices, and Business Profile. Through Slice 5 there is no Settings
route, screen, folder, or toolbar item. Settings
may be introduced later only when concrete settings exist.

Creation remains contextual:

- Today: the primary add action creates an appointment.
- Schedule: the toolbar plus button creates an appointment.
- Clients: the toolbar plus button creates a client.
- Client detail: Add Horse opens a horse form with that client preselected.
- Client detail: Create Invoice opens Client-specific eligible Visit selection.
- Service Locations: the toolbar plus button creates an independent location.
- Services: the toolbar plus button creates an active Service with a required
  name and default USD price.
- Business Profile: Save persists the reusable name and optional invoice
  contact information and default note.
- Horse creation: the user selects an existing service location or creates one
  in a nested sheet and returns with it selected.
- Service-location detail: Add Horse supports creating a horse for that
  location or choosing Add Existing Horse. Existing-horse selection includes
  only horses that pass the Visit-aware relocation rule and are not already
  assigned to the location.

Native back navigation preserves context. No global create flow, custom tab bar,
custom back button, or hidden gesture is used.

Visit creation is contextual to Appointment Detail:

- An Appointment with no Visit offers Start Visit.
- An Appointment with an in-progress Visit offers Resume Visit.
- An Appointment with a completed Visit offers View Visit.
- Visit Detail is shared by Appointment Detail and Horse History.
- Horse Detail contains completed Visit history; there is no global history
  destination.
- Each VisitHorse row in an in-progress editor or completed Visit Detail opens
  its Hoof Photographs collection.

Invoice creation is contextual to Client Detail. It lists only completed Visits
with uninvoiced WorkItems for that Client. Selecting a Visit includes every
eligible WorkItem for that Client, including only that Client's portion of a
mixed-client Visit. Successful generation replaces creation with Invoice Detail.
The Clients More menu also provides the complete Invoice list and reusable
Business Profile editor.

Once a Visit exists, Appointment service location and horse membership are
read-only. Scheduled start, Appointment Notes, and expected duration remain
editable, but changing them must not alter Visit timestamps, location
snapshots, membership, or Horse History ordering.

Changing an existing horse's service location is allowed only when every
Appointment membership has a completed Visit. An Appointment with no Visit or
an in-progress Visit blocks relocation regardless of scheduled date. A
completed Visit releases only its Appointment's relocation block. The
interface never moves, deletes, or rewrites Appointment or Visit records as a
side effect of relocation.

## Lists and Record Hierarchy

Rows prioritize the information needed for the next decision:

- Appointment: start time, service-location name, and selected horses. When
  expected duration is absent, only the start time is shown.
- Client: name first, then available phone or email.
- Service location: name first, then address when supplied.
- Horse: name first, followed by owner and current service location. Safety
  Notes are visibly labeled and announced when present.
- Visit: actual work date, immutable service-location name snapshot, state, and
  each scheduled horse's outcome.
- Horse History: completed Visits ordered newest first, showing work date,
  immutable service-location name, serviced or not-serviced outcome, and a
  Work Notes indication when present.
- Service: name, visible default price, and active or inactive availability.
- Invoice: formatted number, Client snapshot name, invoice date, checked total,
  and explicit Unpaid or Paid text, ordered by number descending.
- Invoice Detail: business and Client snapshots, dates, status, Visit-grouped
  line items, checked total, optional note, and payment date when Paid.

Use standard disclosure indicators when a row navigates. Avoid turning every
row into a card. Secondary metadata may wrap under Dynamic Type; names and
primary actions must remain legible.

Schedule includes appointments from the start of the current local calendar day
onward. It groups appointments by local calendar day, orders groups from
earliest to latest, and orders appointments chronologically within each group.
Appointments before today's local-day boundary are excluded. Past Appointment
history remains excluded. Completed Visit history is reached from Horse Detail.

Appointment rows retain scheduled time, service location, and horses. When a
Visit exists, they add a concise localized In Progress or Completed secondary
status.

## Forms and Validation

Forms group related fields into short, named sections. Required fields are
identified in labels or supporting text, not only after submission. Optional
fields remain visibly optional when ambiguity could slow entry.

Validation occurs at the earliest useful boundary:

- Disable Save when a required value is missing or invalid.
- Keep entered data in place when validation fails.
- Put concise corrective text next to the relevant section or field.
- Use an alert for blocked deletion because it concerns related records, not a
  single field.
- Use a confirmation dialog before a permitted destructive action.

Appointment creation requires a service location, a start date and time, and at
least one eligible horse. Horse selection shows only horses whose current
service location matches the appointment location. Expected duration is
optional and has no automatic value.

Starting a Visit creates one pending outcome for every scheduled horse. Save
Progress permits pending outcomes and keeps the editor open. Complete Visit is
available only when every horse is serviced or not serviced and at least one
horse is serviced.

Work Notes are optional and available only for serviced horses. Changing a
serviced horse with notes to another outcome requires confirmation before the
notes are cleared.

Business Profile requires a normalized business or farrier name. Phone, email,
address, and default invoice note are optional. Invoice creation requires one
valid Business Profile and at least one selected eligible Visit. Invoice and due
dates default to today and 14 calendar days later, remain editable, and the note
prefills from the profile. There is no per-Service or partial line selection.

The Visit editor visibly indicates unsaved changes. Dismissing with a dirty
draft requires confirmation. Discard Unsaved Changes restores the last saved
progress, while Discard Visit is a separate destructive action available only
for an in-progress Visit.

## Empty and Unavailable States

Empty states explain why the screen is empty and offer one relevant next step:

- Today: no appointments today; offer Schedule Appointment.
- Schedule: No scheduled appointments; offer Schedule Appointment.
- Clients: no clients; offer Add Client.
- Service Locations: no locations; offer Add Service Location.
- Client detail: no horses for this client; offer Add Horse.
- Service-location detail: no eligible existing horses; explain that only
  horses assigned elsewhere whose Appointment memberships all have completed
  Visits can be relocated.
- Appointment horse selection: no eligible horses at the selected location;
  explain that a horse must first be assigned there.
- Horse History: no completed visits; explain that completed work will appear
  after a Visit is completed.
- Services: no active candidates while recording work; offer Create Service
  instead of an empty picker.
- Invoices: no invoices; explain that invoices are created from Client Detail.
- Invoice creation: explain when no completed uninvoiced work is available, and
  link directly to Business Profile when its required name is missing.
- Visit or VisitHorse unavailable: explain that the record cannot be loaded and
  disable unsafe actions.

When a feature cannot operate because prerequisite data is missing, state the
prerequisite directly. Do not display an inactive dashboard, fabricated sample
data, or decorative illustration in place of guidance.

Visit history remains readable from immutable service-location snapshots when
the current Barn relationship is unexpectedly missing. In that state, no
service-location navigation affordance is shown.

## Toolbars and Primary Actions

Use system placements:

- Navigation titles describe the current collection or record.
- Plus buttons create the record owned by the current context.
- Save and Cancel use standard sheet toolbar positions.
- Destructive actions live in a menu, swipe action, or detail toolbar as
  appropriate and always follow the defined delete rules.

Frequent actions should be reachable without stretching across the screen.
Primary form completion stays in the standard toolbar so it remains predictable
with the keyboard and assistive technologies.

Save Progress and Complete Visit are distinct, plainly labeled actions.
Destructive Visit discard remains in a menu or confirmation flow rather than
competing visually with completion.

Invoice Detail keeps Share PDF, Mark Paid, and eligible Delete actions in the
native toolbar. Mark Paid and unpaid deletion require native confirmation.
Paid invoices expose neither deletion nor reversal.

## Status and Feedback

Visit state and per-horse outcome remain:

- A Visit is In Progress while `completedAt` is absent and Completed after a
  successful completion save.
- A VisitHorse is Pending, Serviced, or Not Serviced.
- Status and outcome use localized text and are not communicated by color
  alone.
- Completed Visit correction never changes Visit timestamps or state.

Photograph feedback distinguishes:

- Available files that may be opened or deleted.
- Missing canonical files that remain visible as Unavailable metadata records
  and may be deleted.
- Active processing, storage failure, camera unavailability, camera permission
  denial, and the 16-available-photograph limit.
- Protected-data access deferral, which must not be presented as a missing
  photograph.

Invoice status is always visible as Unpaid or Paid text. PDF preparation failure
leaves the saved Invoice unchanged and offers Retry and Cancel. Generated PDFs
use persisted snapshots only and remain available for the lifetime of the
native share sheet.

Other feedback remains limited to facts the app currently knows:

- Safety Notes are presented as clearly labeled text and are announced by
  VoiceOver.
- Validation explains missing or incompatible data.
- Successful saves dismiss to the owning list or detail hierarchy, where the
  created record is immediately visible.
- A blocked deletion alert names the relationship that must be resolved first.

Use haptics sparingly for meaningful save, selection, warning, or destructive
confirmation. Respect Reduce Motion and do not add continuous or decorative
animation.

## Field Readiness and Accessibility

- Use semantic system colors and sufficient contrast in Light Mode, Dark Mode,
  and Increased Contrast.
- Test key screens at large accessibility text sizes without clipped labels,
  hidden values, or inaccessible actions.
- Maintain at least 44 by 44 point interactive targets.
- Provide meaningful VoiceOver labels, values, hints, grouping, and reading
  order.
- Announce horse selection state and Safety Notes.
- Do not encode selection, warnings, or validation by color alone.
- Prefer short inputs, sensible keyboard types, and system content types for
  phone and email.
- Preserve entered form data across nested service-location creation.
- Announce each horse's Visit outcome and selection state.
- Give Work Notes a visible localized label and an explicit VoiceOver label.
- Keep Save Progress, Complete Visit, and destructive discard distinguishable
  in the accessibility hierarchy.
- Keep essential actions usable with one hand and without precision gestures.
- Announce Invoice Visit selection state, line-item amount, checked total, and
  payment status without relying on color.

## Explicitly Excluded Patterns

Do not introduce:

- Western, rustic, veterinary, or cartoon styling.
- Horseshoe decoration or ornamental horse imagery.
- Generic SaaS dashboard layouts.
- Custom navigation, tab bars, back buttons, or form controls.
- Manually simulated Liquid Glass or glass content cards.
- Gradients, nested cards, card-on-card layouts, or excessive corner radii.
- Oversized headings, decorative icon containers, or ornamental motion.
- Invented interaction patterns or gesture-only actions.

## Design Acceptance

A current-slice screen is ready only when it:

- Uses native controls and navigation on both iOS 18 and iOS 26.
- Remains legible outdoors and at supported Dynamic Type sizes.
- Exposes its primary action clearly and contextually.
- Communicates empty, invalid, blocked, and destructive states in plain
  language.
- Preserves the approved data relationships in its labels and actions.
- Adds no visual or interaction promise for deferred functionality.
