# Slice 7 — Next Appointment Assistance Design

**Status:** Approved; implementation in progress

**Date:** 2026-08-03

**Execution status (2026-08-04):** Units 1 through 5 are complete. Unit 6
acceptance, relaunch, accessibility, and platform-closure work has not started.
Slice 7 is not complete until those remaining gates pass.

## Purpose

Slice 7 closes FarrierFlow's core service cycle by helping the farrier schedule
the next visit after completed work. It uses existing Visit truth and each
Horse's saved appointment interval to prepare a normal Appointment draft. The
farrier reviews and saves that draft; FarrierFlow never creates an Appointment
automatically.

The feature remains local-first, offline, owner-operated, and iPhone-first.

## Chosen Approach

Use a dismissible next-Appointment assistant immediately after Visit
completion. It shows the serviced Horses, each truthful suggested date, the
earliest group date, and any existing future Appointment. Continue opens the
existing Appointment editor with an explicit prefilled draft.

The same assistant remains available later from the completed Visit detail
reached through Horse History.

### Alternatives Considered

1. **Assisted draft after Visit completion — chosen.** Completes the workflow
   with current records, preserves user control, and requires no new persisted
   status or schema.
2. **Persisted follow-up queue on Today — rejected.** Adds a second task system,
   follow-up completion state, dismissal semantics, and dashboard pressure
   before they are needed.
3. **Automatic next-Appointment creation — rejected.** Risks duplicates and
   silently treats a Horse interval as a commitment rather than a preference.

## Product Boundary

- Assist only from a completed Visit.
- Use live Horse interval and Service Location eligibility with immutable Visit
  and source-Appointment facts.
- Produce one ordinary Appointment through the existing Schedule persistence
  boundary.
- Keep Service Location and Horse selection visible and editable.
- Apply existing new-Appointment duration defaults normally.
- Copy no Appointment notes, Work Notes, WorkItems, photographs, prices, or
  Invoice state into the new Appointment.
- Add no reminder, notification, follow-up queue, automatic creation, recurring
  series, account, or network requirement.

## Primary Flow

1. The farrier completes a Visit successfully.
2. The Visit editor dismisses only after the completion transaction succeeds.
3. The presenting surface opens **Next Appointment** for that completed Visit.
4. The assistant shows every Horse from the Visit:
   - Serviced Horses are preselected when eligible.
   - Not Serviced Horses remain visible and unselected.
   - Already-scheduled, moved, unavailable, or superseded Horses show their
     truthful state and are not preselected.
5. Each eligible serviced Horse shows its saved interval and suggested date.
6. The assistant proposes one start date using the earliest selected serviced
   Horse date and the source Appointment's local start time.
7. The farrier may change Horse selection or choose **Not Now**.
8. **Continue** opens the existing Appointment editor with Service Location,
   selected Horses, and suggested start prefilled.
9. The farrier may edit every value. Save creates one normal Appointment.
10. Successful save routes to the existing Appointment detail so the scheduled
    record is visible and verifiable.

No assistant dismissal or editor cancellation modifies the completed Visit or
creates an Appointment.

## Suggestion Rules

### Projection Boundary and Stable Time

Each assistant load is one projection. Its caller captures one `now` value and
injects that exact value into the projection. Future-Appointment detection,
past-suggestion comparison, and next-half-hour fallback all use that value.
Suggestion rules and views must not read `Date.now` or `.now` again during the
projection. Retry and reopening start a new projection and may inject a new
`now` value.

The projection requires a valid source Appointment. Valid means:

- The Visit is completed with `completedAt >= startedAt`.
- The Visit resolves an Appointment and the Appointment resolves that same
  Visit.
- The Visit and Appointment resolve the same valid source Service Location.
- AppointmentHorse and VisitHorse memberships are unique, inverse-valid, and
  contain exactly the same Horse identifiers.

If any fact is absent or inconsistent, the whole projection fails closed with
**Next Appointment Unavailable**, Retry, and Done. It does not substitute the
Visit snapshots or the Horse's current Service Location, fabricate a source
time, or open an unseeded Appointment editor.

### Per-Horse Date

For each eligible serviced Horse:

1. Use the completed Visit's `startedAt` local calendar day as the work date.
2. Add `Horse.appointmentIntervalWeeks` with Calendar week arithmetic.
3. Apply the source Appointment's local hour and minute to that resulting day.
4. Preserve Calendar behavior across daylight-saving transitions; do not add a
   fixed number of seconds.

Example: work performed Monday at a source Appointment scheduled for 9:00 AM,
with a six-week Horse interval, suggests Monday at 9:00 AM six weeks later.

The Horse interval is a scheduling preference, not medical urgency. Copy must
say **Suggested**, never **Due**, **Overdue**, or **Late**.

### Group Date

- Preselect every eligible serviced Horse.
- Show each Horse's individual suggested date.
- Prefill the Appointment with the earliest suggested date among selected
  serviced Horses.
- When selection changes, recalculate the group date only while the farrier has
  not manually changed the proposed date or time.
- After a manual date or time edit, that edit is authoritative.
- Selecting a Not Serviced Horse adds no inferred date. If no selected Horse
  has a suggested date, use the ordinary next-half-hour new-draft rule with the
  projection's injected `now` and label the absence of a follow-up suggestion.

### Past Suggestions

When the assistant is opened later and the calculated suggested date is before
the projection's injected `now`:

- Continue showing the historical suggested date for context.
- Do not describe it as overdue.
- Prefill the Appointment editor with its next available half-hour rather than
  creating a past Appointment draft.

## Horse Eligibility and Duplicate Protection

The assistant evaluates every Horse in the source Visit independently.

An eligible Horse must:

- Resolve from the VisitHorse relationship.
- Have a valid Client.
- Still belong to the source Service Location.
- Have a positive appointment interval.
- Have no newer completed serviced Visit.
- Have no future Appointment at the time the assistant loads.

For newer-work detection, consider only a different Visit for the same Horse
whose outcome is Serviced and whose completion is valid
(`completedAt >= startedAt`). Explicitly exclude the source Visit identifier
before comparing records. A candidate is newer only when it sorts before the
source Visit by this total order:

1. `startedAt`, descending.
2. `completedAt`, descending.
3. persistent Visit identifier, ascending.

Therefore equal timestamps do not remain ambiguous: the lower persistent
identifier sorts first. This matches Horse History's chronological priorities.
An otherwise qualifying Visit that sorts after the source is older and does not
supersede it.

Outcomes:

- **Serviced and eligible:** preselected with suggested date.
- **Not Serviced and otherwise eligible:** available but unselected, with no
  suggested date.
- **Future Appointment exists:** unavailable in this assistant; show its start
  date and Service Location.
- **Newer completed serviced Visit exists:** unavailable; direct the farrier to
  use the newer Visit's follow-up action.
- **Horse moved:** unavailable for this source Service Location; show its
  current location when valid.
- **Invalid non-source current graph:** after the source Appointment and its
  membership have passed projection validation, fail closed only the affected
  Horse for invalid Client, current-location, future-Appointment, or candidate
  Visit relationships; keep other Horses usable.

Future-Appointment detection excludes the source Appointment, then uses
existing AppointmentHorse membership and a start date at or after the
projection's injected `now`. No follow-up provenance or duplicate Boolean is
persisted. A farrier who intentionally needs an additional Appointment can use
the normal Schedule flow, where the choice is explicit.

Reopening always recomputes from the current graph. If a previously saved
Appointment contains only a subset of the source Visit's Horses, those Horses
show **Already Scheduled**, remain unselected, and cannot be selected in this
assistant. Every remaining Horse is evaluated independently: eligible Serviced
Horses are preselected, eligible Not Serviced Horses remain selectable and
unselected, and moved, superseded, or invalid Horses retain their truthful
states. The group suggestion is recomputed only from the remaining selected
Serviced Horses. The assistant remains actionable while at least one Horse is
selectable; it never edits or merges into the saved Appointment. If that future
Appointment is edited to remove a Horse, deleted, or is no longer future at a
later projection, the affected Horses become eligible again when all other
rules pass.

If no Horse is selectable, the assistant shows the factual reason and offers
Done. It does not open an empty Appointment editor.

## Assistant Interface

Use a native NavigationStack and Form or List presented as a sheet.

### Summary

- Title: **Next Appointment**
- Source Service Location
- Source work date
- Proposed group date when available

### Horses

Each row shows:

- Horse name
- Visit outcome
- Saved interval for serviced Horses
- Suggested date when available
- Existing Appointment or eligibility explanation when unavailable
- Native selection state when selectable

Keep the list flat. Do not use cards, a calendar grid, completion animation, or
custom selection controls.

### Actions

- **Not Now** dismisses without persistence.
- **Continue** is the single primary action and is disabled until at least one
  eligible Horse is selected.
- Appointment-editor Cancel returns to the assistant with the transient
  selection intact.

## Later Recovery

A completed Visit detail exposes **Schedule Next Appointment** when at least one
Visit Horse can enter the assistant. Otherwise it shows the current scheduled,
moved, superseded, or unavailable state. Horse History already routes to that
Visit detail, so no new tab, global follow-up destination, or Today queue is
added.

The action reloads current eligibility every time. It never restores stale
assistant state from a previous dismissal. If all relevant Horses have newer
work or future Appointments, Visit detail shows that truthful status instead of
an actionable button.

Today retains its existing ranking. Completing a Visit may still make Invoice
creation the next Today action; next-Appointment assistance does not compete in
that ranking.

## Architecture and Ownership

- Schedule owns suggestion rules, assistant projection, assistant UI, and the
  immutable seed passed to Appointment creation.
- Visits emits the successfully completed Visit identifier. It does not create
  or save the follow-up Appointment.
- Today and Appointment Detail may present the Schedule-owned assistant after
  their Visit editor reports completion.
- Visit Detail presents the same assistant for later recovery.
- AppointmentEditorModel remains the only Appointment draft validation and
  save boundary.

Suggested implementation units:

- `NextAppointmentSuggestionRules`: actor-neutral Calendar and selection rules.
- `NextAppointmentAssistantModel`: main-actor SwiftData projection using Visit,
  VisitHorse, Horse, Appointment, and AppointmentHorse truth.
- `NextAppointmentSeed`: immutable Service Location, start date, and selected
  Horse identifiers for a new Appointment draft.
- `NextAppointmentAssistantView`: native presentation and actions only.

Do not add a new SwiftData model, schema version, completion flag, source-Visit
relationship, repository abstraction, or dependency-injection framework.

## Persistence and Relaunch

- The assistant is transient and writes nothing.
- Saving uses the existing Appointment and AppointmentHorse graph.
- Relaunch before Save loses assistant edits because no Appointment exists; the
  action remains recoverable from completed Visit detail.
- Relaunch after Save shows the normal persisted Appointment and duplicate
  detection recognizes it.
- A failed save keeps the Appointment draft visible and leaves the completed
  Visit unchanged.

## Failure Behavior

- Visit completion failure never opens the assistant.
- Suggestion load failure shows a native unavailable state with Retry and Done.
- Missing or inconsistent source Appointment or source Service Location fails
  the whole projection closed; no partial Horse projection is shown.
- Calendar failure with otherwise valid records removes the follow-up date seed
  and explains the failure. Continue opens the ordinary Appointment editor with
  its visible new-draft time default; no calculated date is fabricated.
- Invalid source Service Location or source Visit membership fails the whole
  projection. Corrupt non-source current relationships fail only the affected
  Horse after that source validation passes.
- If eligibility changes before Save, existing Appointment validation rejects
  stale selections and preserves the draft for correction.

## Accessibility and Field Readiness

- Announce each Horse in this order: name, outcome, interval, suggested date,
  selection or unavailable reason.
- Do not communicate Serviced, Not Serviced, selected, moved, or already
  scheduled state through color alone.
- Use localized dates and times with the SwiftUI environment Locale and an
  injected Calendar for rules.
- Preserve Dynamic Type reflow without fixed heights.
- Keep primary actions at least 44 by 44 points and reachable one-handed.
- Respect Reduce Motion; the flow needs no essential animation.
- Support Light Mode, Dark Mode, Increased Contrast, VoiceOver, iOS 18, and
  iOS 26 with native controls.

## Testing Contract

Focused coverage must prove:

- Calendar-week suggestions and local-time preservation, including a
  daylight-saving transition.
- Earliest-date selection for several Horses with different intervals.
- Selection-driven recalculation stops after a manual date/time override.
- Not Serviced Horses receive no inferred date.
- Past suggestions never prefill a past Appointment.
- Future Appointments, newer serviced Visits, moved Horses, missing Clients,
  invalid intervals, and missing relationships produce the specified states.
- Mixed-client Horses at one Service Location can share the follow-up
  Appointment.
- Dismissal and cancellation create no record.
- Save creates one valid Appointment through existing rules and survives
  persistent-store reopening.
- Visit completion presents the assistant only after successful persistence.
- Later recovery from Horse History reaches the same current projection.
- VoiceOver order, Dynamic Type, and disabled primary-action state remain clear.

Final integration should exercise one multi-Horse Visit with different
intervals, deselection, manual date override, Not Now recovery, duplicate
recognition after Save, and relaunch persistence using serial single-simulator
commands under the repository resource policy.

## Exact Acceptance Flow

1. Complete a Visit containing two Serviced Horses with different intervals
   and one Not Serviced Horse.
2. Verify both Serviced Horses are selected and show individual suggestions.
3. Verify the Not Serviced Horse is unselected without a suggestion.
4. Verify the group date equals the earliest serviced-Horse suggestion at the
   source Appointment's local time.
5. Choose Not Now and verify no Appointment was created.
6. Open the completed Visit through Horse History and choose Schedule Next
   Appointment.
7. Deselect the earliest Horse and verify the untouched group date updates.
8. Manually change the date, change selection again, and verify the manual date
   remains authoritative.
9. Continue, review the normal Appointment form, and save.
10. Verify one Appointment with the selected Horses and source Service Location
    appears in Schedule and survives relaunch.
11. Reopen the source Visit and verify the saved future Appointment prevents a
    duplicate selection for those Horses.

## Explicit Exclusions

- Automatic Appointment creation or recurring series.
- Notifications, reminders, badges, urgency, overdue language, or follow-up
  task persistence.
- Today ranking changes or a new follow-up dashboard.
- A new model, migration, source-Visit link, or scheduled Boolean.
- Copying source Appointment notes, Work Notes, Services, prices, photographs,
  Invoice data, or payment state.
- Scheduling Horses at a Service Location different from their current one.
- Customer-facing confirmation, messaging, accounts, networking, or calendar
  integration.
- Payment processing, export, subscriptions, or backup.
