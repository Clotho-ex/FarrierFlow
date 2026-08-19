---
name: FarrierFlow
description: A native field book for running an independent farrier business.
---

<!-- SEED: established with the user before implementation; re-run $impeccable document once there's code to capture the actual tokens and components. -->
<!--
THESIS: FarrierFlow turns one continuous service cycle into a legible field workline; it refuses both blank form stacks and generic card dashboards.
OWN-WORLD: Native iOS surfaces, Survey Ink action fields, ruled alignment, compact metadata, generous action spacing, and flat tonal hierarchy.
STORY: The farrier sets up the business once, sees the next truthful action, completes work in sequence, and retains connected history.
FIRST VIEWPORT: Business identity and date lead into a state-adaptive Run Sheet. Next Stop or active Visit owns one edge-to-edge action field; remaining work continues chronologically below.
FORM: Field Book world with approved Run Sheet synthesis of Next Stop Band and Active Work; surface seed 6dbeb15b. Both rolls were degraded and supplied no catalog challengers.
-->

# Design System: FarrierFlow

## Overview

**Creative North Star: "The Field Book"**

FarrierFlow should feel like a precise field instrument that happens to be an
iPhone app: quick to scan in glare, comfortable in one hand, and calm when the
workday becomes busy. Its visual structure borrows from a modern surveyor's
field book—clear ruled alignment, concise annotations, chronological flow, and
marks that show where work stands—without imitating paper texture or vintage
equipment.

The system is expressive through information choreography, not decoration.
Business identity, real schedule context, photographs, status, and the next
valid action provide personality. Standard SwiftUI navigation and controls
remain visible and familiar. The interface never becomes a themed notebook,
western artifact, veterinary record, or generic SaaS dashboard.

**Key Characteristics:**

- Action-led rather than form-led.
- Flat, high-contrast, and outdoor-readable.
- Personalized with the farrier's saved business identity.
- Chronological, with one continuous workline from appointment to payment.
- Native on iOS 18 and iOS 26, including platform materials and control
  behavior.
- Quiet at rest; motion and haptics confirm real state changes only.

Release 1.0 adds a native subscription surface without creating a second visual
system. Apple's `SubscriptionStoreView` owns localized plan merchandising and
purchase controls. FarrierFlow supplies only a concise Field Book header and
truthful workflow explanation.

## Colors

Use a restrained strategy: semantic iOS neutrals plus one blue-green
**Survey Ink** accent. The existing Accent Color asset is the starting primary
and remains subject to implementation-time contrast validation. System red,
orange, and green communicate destructive, warning, and success states only;
they are not brand decoration.

**The Ink Rarity Rule.** Survey Ink identifies the primary action, current
selection, and active progress. Today may spend it on one edge-to-edge Run
Sheet action field for a current-day Appointment or active Visit. It must not
tint every label, icon, divider, or container.

**The Daylight Rule.** Primary content and actions must remain immediately
legible in Light Mode, Dark Mode, and Increased Contrast. Never place essential
text on a photographic or low-contrast tinted field.

## Typography

Use the San Francisco system family and semantic SwiftUI text styles. The
Field Book character comes from disciplined hierarchy and alignment, not a
custom typeface. Use monospaced digits only for times, invoice numbers, money,
and progress counts where stable alignment improves scanning.

- `largeTitle` and `title`: screen identity only; never oversized dashboard
  display text.
- `title2` and `headline`: next action, record name, and section priority.
- `body` and `callout`: instructions, values, and operational detail.
- `subheadline`, `footnote`, and `caption`: metadata and secondary explanation;
  never required recovery instructions by themselves.

**The One-Glance Rule.** On every operational screen, the record, its state,
and the next valid action must be distinguishable without reading all body
copy.

**The Ownership Rule.** Read-only subscription state must remain calm and
unambiguous. Today shows one compact notice with a Subscription action; record
screens continue to emphasize the owner's data rather than repeating warnings.
Existing Invoice PDF viewing and sharing remain ordinary native actions.

## Layout

Primary screens use one vertical reading path. Today is a state-adaptive **Run
Sheet**: saved business identity and date, one edge-to-edge action field, then
remaining chronological work. A scheduled state shows Next Stop, time, Service
Location, Horses, status, and Open Appointment. An active Visit replaces that
content with real resolved-Horse progress and Resume Visit. The promoted record
is not repeated immediately below. Lists remain full-width native lists or
scroll content; they do not become grids of interchangeable cards.

The signature spatial device is a **workline**: a restrained leading rule or
native progress treatment connecting real workflow states. It may organize a
Visit's horse completion or an appointment's progress from scheduled work to
invoice status. First run stays a single-field identity form rather than
manufacturing a setup workline. It never becomes a custom navigation control
or exposes deferred next-appointment automation.

Forms use progressive disclosure. Show required decisions first, prefill saved
owner defaults and contextual relationships, and place optional notes or
overrides in secondary sections. One screen should not ask the user to decide
business identity, customer data, location, work, and billing policy at once.

At accessibility Dynamic Type sizes, horizontal metadata groups reflow
vertically. Frequent actions remain within the lower comfortable reach area
when native presentation permits. Touch targets remain at least 44 by 44
points.

## Elevation & Depth

FarrierFlow is flat by default. Use native grouped backgrounds, separators,
selection, toolbar materials, sheets, and navigation depth. Do not add custom
drop shadows, floating glass cards, bevels, or paper textures. A sheet may feel
elevated because iOS presents it that way; content does not manufacture a
second elevation system inside it.

**The Native Depth Rule.** Navigation and system presentation create depth.
Content hierarchy uses spacing, type, tone, and rules.

## Shapes

Use shapes supplied by native controls and containers. The Run Sheet action
field meets the screen edges instead of floating as a rounded card. Its primary
button keeps native shape and behavior. Rows, form sections, status labels, and
photographs must not each become rounded cards.

Progress marks and the workline use precise circles, rules, and aligned edges.
These are functional state indicators, not decorative icon containers.

## Do's and Don'ts

### Do:

- **Do** personalize the hub with persisted business identity and real work.
- **Do** let the Run Sheet action field change from Next Stop to active Visit
  without moving the user into a different dashboard.
- **Do** lead each state with one next valid action and keep alternate actions
  native and secondary.
- **Do** use a truthful progress count or workline when completion has defined
  steps.
- **Do** save reusable owner defaults once and visibly show when a field is
  using one.
- **Do** use real hoof photographs only in their approved VisitHorse context.
- **Do** preserve standard `TabView`, `NavigationStack`, `List`, `Form`,
  toolbars, sheets, alerts, and confirmation dialogs.
- **Do** respect Dynamic Type, VoiceOver, Reduce Motion, Increased Contrast,
  Light Mode, and Dark Mode from the first composition.
- **Do** use native StoreKit pricing, recurring-period, trial, restore, policy,
  and purchase presentation.
- **Do** preserve complete record navigation and existing document access in
  read-only mode.

### Don't:

- **Don't** build a generic metrics dashboard, tile grid, or card-on-card home
  screen.
- **Don't** use western, rustic, veterinary, cartoon, horseshoe, parchment, or
  ornamental horse styling.
- **Don't** add gradients, custom tab bars, custom back buttons, simulated
  Liquid Glass, decorative icon boxes, or continuous animation.
- **Don't** fabricate urgency, expiring rewards, streaks, customer evidence,
  operational data, or progress the app cannot prove.
- **Don't** use countdowns, fake savings, obstructive paywall overlays, repeated
  renewal warnings, or hidden existing records to pressure a purchase.
- **Don't** use color alone for status, selection, warnings, or completion.
- **Don't** hide record-specific truth—Client, Horse, Service Location, Visit
  outcome, performed work, or price—behind an owner-level default.
