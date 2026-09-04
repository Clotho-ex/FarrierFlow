---
name: FarrierFlow
description: A native field book for running an independent farrier business.
---

<!-- SEED: established with the user before implementation; re-run $impeccable document once there's code to capture the actual tokens and components. -->
<!--
THESIS: FarrierFlow turns one continuous service cycle into a legible field workline; it refuses both blank form stacks and generic card dashboards.
OWN-WORLD: Warm native iOS surfaces, precise orange actions, ruled alignment, compact metadata, generous action spacing, and flat tonal hierarchy.
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
system. FarrierFlow's SwiftUI list projects RevenueCat's current Offering into
localized annual and monthly plan rows, truthful billed price/period copy,
purchase progress, restore, retry, legal links, and Apple's native Manage
Subscription sheet. It does not use a generic vendor paywall or external
checkout.

Release onboarding is a concise Field Briefing: required Business identity, a
calm workflow briefing, then Subscription. The briefing carries the workflow in one
vertical Appointment-to-Payment workline. Every stage has equal visual weight:
Neutral icons and a thin connecting line carry the relationship, while
primary titles and short secondary benefits keep the sequence useful without
making it a tutorial. A centered brand lockup and muted two-line field headline
establish hierarchy above the leading-aligned workline, with deliberate space
separating product identity from workflow context. Business, Briefing, and
Subscription share one adaptive Field Book background: warm cream in Light
Mode and warm charcoal in Dark Mode. Raised identity controls use a related
tonal surface; no onboarding action sits on a separate material strip.
Business Continue, Briefing Continue, and onboarding Subscription Continue use the
same native prominent control without extra label height, so platform sizing,
states, and interaction remain consistent.

Business presents its centered hero and identity form as one vertically balanced
composition: ownership prompt, short trust-led reason, focused field, and centered
invoice/change-later guidance. The form remains the visual center of gravity
rather than splitting the screen into unrelated empty regions.
Its hero scrolls away into a standard inline navigation title. Subscription uses
the same title behavior, one capsule Monthly/Yearly selector, and one raised
detail panel that changes billing/value context without inventing entitlement
differences. Yearly is selected by default and may show only StoreKit-derived
savings and monthly-equivalent values. The native
Continue action retains a truthful trial or renewal disclosure immediately
below it. The selected billing segment uses `brandTint` with readable
`brandActionText`; solid orange is reserved for the purchase CTA. Brand orange
marks only focus, selection, and the primary action. Business and Subscription
enter with a short Reduce-Motion-safe fade and rise. Briefing uses one authored
top-to-bottom reveal: mark, product name,
supporting line, workline title, then each workline stage. Only those four
workline arrivals produce a light haptic; native Continue and plan-selection
interactions use restrained confirmation and selection feedback. Reduce Motion
reveals content immediately and suppresses automatic haptics. The system launch
screen contains only the app mark on a matching adaptive background. There is
no progress bar, animated splash, carousel, feature grid, or success screen.

## Record and Status Alignment

List rows use SwiftUI `.badge(Text(...))` for status, without custom status
containers or decorative status symbols. Native layout owns trailing badge placement.
At accessibility text sizes, use plain status text below the record instead so a
trailing badge cannot squeeze its label into a narrow column. Paid/completed text
may use semantic green; ordinary
unpaid/pending labels use readable secondary text without an extra warning
treatment. Actual warning callouts retain amber. Hide navigation-link disclosure
indicators app-wide with `RecordNavigationLink`, using the native visibility
modifier on iOS 26 and a shared compatibility treatment on iOS 18. Retain native
NavigationLink interaction, accessibility, and back navigation. Keep supporting record text
leading-aligned. Invoice detail amounts and captions share a trailing edge in
two-column layouts and a leading edge when stacked.

## Colors

Use the centralized `ColorTokens` palette: `#BF5700` brand actions, warm cream
`#F4F0EB` canvases, `#FAF8F5` surfaces, and `#24211E` readable ink. Dark Mode
uses warm charcoal `#171513` / `#211E1B` / `#2A2622` and `#E06C12` actions.
Green means paid or completed, amber means attention, red means failed or
destructive, and blue-gray is reserved for neutral system information.

**The Orange Rarity Rule.** Orange identifies the primary action, current
selection, and active progress. Today uses a quiet brand tint for its promoted
action, not a saturated orange field. Ordinary icons, metadata, cards, and
dividers remain neutral. Small action text uses the darker brand shade on
light surfaces; solid primary actions retain `#BF5700`. Never communicate
important state through color alone.

Primary-button labels are white in Light Mode and warm ink in Dark Mode;
disabled labels use a neutral readable foreground with native disabled surfaces.
Small orange action text uses `brandActionText` (`#8F4100` / `#E57820`), not
the solid-button fill, to maintain contrast on tinted surfaces. Dark semantic
tints are opaque so their contrast does not change when nested in a selected
control. The print-only invoice renderer keeps its separate document palette.

**The Daylight Rule.** Primary content and actions must remain immediately
legible in Light Mode, Dark Mode, and Increased Contrast. Never place essential
text on a photographic or low-contrast tinted field.

## Typography

Use the San Francisco system family with the Rounded design applied at the app
root and semantic SwiftUI text styles throughout. The Field Book character comes
from disciplined hierarchy and alignment, not a custom typeface. Use monospaced
digits only for times, invoice numbers, money, and progress counts where stable
alignment improves scanning.

- `largeTitle` and `title`: screen identity only; never oversized dashboard
  display text. Onboarding may use a centered scaled `largeTitle` hero that
  hands off to the native inline navigation title when scrolled.
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
selection, toolbar materials, sheets, and navigation depth. One adaptive Field
Book elevation token is reserved for genuinely raised custom surfaces: the
onboarding identity field, Pro selector and detail panel, and transient
operation or retry overlays. Native lists, forms, Today content, rows, and
ordinary controls remain shadow-free. Do not add floating glass cards, bevels,
or paper textures.

**The Native Depth Rule.** Navigation and system presentation create depth.
Content hierarchy uses spacing, type, tone, and rules.

## Shapes

Use shapes supplied by native controls and containers. The Run Sheet action
field meets the screen edges instead of floating as a rounded card. Its primary
button keeps native shape and behavior. Rows, form sections, status labels, and
photographs must not each become rounded cards.

Progress marks and the workline use precise circles, rules, and aligned edges.
These are functional state indicators, not decorative icon containers.

Onboarding uses borders only when they communicate a real decision or grouping:
the Business field focus state and the selected Pro period. The compact Pro
selector, its single changing detail panel, and the identity field use the one
adaptive elevation token to separate them from the continuous Field Book
background without introducing nested cards or glass.

## Do's and Don'ts

### Do:

- **Do** personalize the hub with persisted business identity and real work.
- **Do** let the Run Sheet action field change from Next Stop to active Visit
  without moving the user into a different dashboard.
- **Do** lead each state with one next valid action and keep alternate actions
  native and secondary.
- **Do** use a truthful progress count or workline when completion has defined
  steps. Welcome may name Appointment, Visit, Invoice, and Payment once in a
  concise statement; it is context, not interactive progress.
- **Do** save reusable owner defaults once and visibly show when a field is
  using one.
- **Do** use real hoof photographs only in their approved VisitHorse context.
- **Do** preserve standard `TabView`, `NavigationStack`, `List`, `Form`,
  toolbars, sheets, alerts, and confirmation dialogs.
- **Do** respect Dynamic Type, VoiceOver, Reduce Motion, Increased Contrast,
  Light Mode, and Dark Mode from the first composition.
- **Do** show RevenueCat-projected StoreKit pricing and recurring periods in
  native SwiftUI, with restore, policy, retry, and purchase progress.
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
