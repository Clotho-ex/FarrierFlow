# FarrierFlow App Store Screenshot Storyboard

**Status:** Planning only. Do not modify or upload live App Store screenshots.
This is not authorization to create final marketing images.

**Target:** US App Store, iPhone-first FarrierFlow v1.0.1

## Story principle

Tell one connected working-day story rather than seven unrelated feature
cards:

```text
Plan the day → arrive prepared → know the horse → record the work
→ invoice it → track payment → book the next visit
```

The headline should state the outcome. The actual interface should carry the
proof. Use deterministic fictional fixtures only, never real customer or
business information. Keep the native Field Book interface legible and avoid
decorative dashboards, invented metrics, or features that do not ship.

## Proposed sequence

### 1. Run the whole day from one place

- **Purpose:** Establish FarrierFlow as a complete working-day system, not a
  single-purpose record book.
- **Target screen:** Today Run Sheet with a realistic mix of upcoming and
  completed appointments.
- **Draft headline:** `Your whole workday, in hand`
- **Supporting copy:** `See what is next and keep every job moving.`
- **Required fixture/state:** Three fictional appointments across two service
  locations; one completed visit; clear next action; no overdue alarmism or
  fabricated revenue totals.
- **Visual hierarchy:** Today title and next appointment first, orange reserved
  for the primary action, completed work quieter below. The screen should be
  understandable before reading supporting copy.

### 2. Keep the next work clear

- **Purpose:** Show scheduling intent and the connection between location,
  client, horses, and planned work.
- **Target screen:** Schedule or Appointment detail/editing screen.
- **Draft headline:** `Know where you are going next`
- **Supporting copy:** `Plan appointments around the horses and work involved.`
- **Required fixture/state:** One upcoming appointment at a fictional barn with
  two fictional horses and scheduled service context.
- **Visual hierarchy:** Date/time and service location lead; horse/work context
  follows. Avoid showing a keyboard, validation error, or empty form.

### 3. Arrive with the horse's history

- **Purpose:** Demonstrate continuity across visits.
- **Target screen:** Horse detail/history.
- **Draft headline:** `Carry the history into every visit`
- **Supporting copy:** `Review prior work, outcomes, and hoof photos in the field.`
- **Required fixture/state:** A fictional horse with two completed historical
  visits, distinct dates, service summaries, and at least one hoof-photo count.
- **Visual hierarchy:** Horse identity and most recent history lead. Use enough
  history to prove continuity without creating a dense wall of records.

### 4. Record the work while it is fresh

- **Purpose:** Show real field participation rather than office-only data entry.
- **Target screen:** Active Visit editor with work and Hoof Photos visible.
- **Draft headline:** `Capture the work at the horse`
- **Supporting copy:** `Record services, outcomes, notes, and hoof photos as you go.`
- **Required fixture/state:** An in-progress fictional two-horse visit; one horse
  serviced, the other still pending; safe, non-identifying hoof images created
  specifically for marketing fixtures.
- **Visual hierarchy:** Current horse and completion state first, service/work
  controls second, Hoof Photos row clearly labeled. Do not imply image analysis
  or automated diagnosis.

### 5. Turn completed work into an invoice

- **Purpose:** Show the transition from field work to billable administration.
- **Target screen:** Invoice detail or generated invoice preview.
- **Draft headline:** `Invoice the visit without retyping it`
- **Supporting copy:** `Build a clear invoice from work already completed.`
- **Required fixture/state:** A fictional completed visit linked to one invoice
  with realistic but non-promotional line items and totals.
- **Visual hierarchy:** Invoice status, amount due, client/location snapshot,
  line items, and Share action should be visible. Avoid claims about automatic
  payment processing; FarrierFlow shares invoices and records payment status.

### 6. Keep payment status visible

- **Purpose:** Close the administrative loop without implying a payment gateway.
- **Target screen:** Paid Invoice detail.
- **Draft headline:** `Know what has been paid`
- **Supporting copy:** `Record payment status and evidence alongside the invoice.`
- **Required fixture/state:** The same fictional invoice transitioned to Paid,
  with a fictional date and method and no sensitive reference or note.
- **Visual hierarchy:** Paid status and amount lead; evidence appears as
  supporting detail. Do not show card entry, bank information, or imply that
  FarrierFlow moves money.

### 7. Leave with the next visit planned

- **Purpose:** Demonstrate the full-loop differentiator.
- **Target screen:** Next Appointment assistance followed by the saved upcoming
  appointment if one frame can show the result truthfully.
- **Draft headline:** `Finish today with the next visit set`
- **Supporting copy:** `Carry the right horses and timing into a new appointment.`
- **Required fixture/state:** A completed fictional visit with interval-based
  follow-up suggestions and a successfully saved next appointment.
- **Visual hierarchy:** Suggested date and selected horses lead, with the primary
  Continue/Save action clear. Do not suggest reminders, automatic booking, or
  customer messaging.

## Fixture continuity

Use one coherent fictional business day across all frames:

- A fictional farrier business name created only for marketing fixtures.
- Two fictional clients/service locations.
- Three to four fictional horses reused consistently.
- Plausible services and dates with no resemblance to real customer records.
- One visit that becomes one invoice, one paid state, and one next appointment.

Keep all copy, names, dates, amounts, photographs, and addresses visibly
fictional yet professional. Avoid “test,” “demo,” or debug labels in final
screenshots.

## Production notes

- Capture from the final shipping candidate after privacy and metadata review.
- Use the current primary iPhone screenshot size accepted by App Store Connect;
  verify requirements at production time rather than assuming the v1.0 sizes.
- Keep device appearance, text size, color scheme, locale, time zone, and fixture
  state consistent across the sequence.
- Check Light and Dark appearance, but choose one coherent storefront story
  unless alternating modes serves a deliberate narrative.
- Ensure headlines remain legible at thumbnail scale and do not cover native
  navigation, primary actions, status, or important record content.
- Do not include ratings, testimonials, customer counts, revenue claims,
  competitor logos, Apple Ads performance, or functionality absent from the
  app.

## Review gate

Before producing final images, verify every screen and claim against the final
v1.0.1 build, the approved metadata, Apple's current screenshot specifications,
and the fictional-fixture privacy checklist. No live screenshot change is
authorized by this storyboard.
