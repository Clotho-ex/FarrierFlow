# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

FarrierFlow is for independent farriers in the United States. Its primary use
case is managing work while standing at a barn, often outdoors and with only one
hand available.

## Product Purpose

FarrierFlow supports the complete service cycle for a horse:

appointment → horse history → work performed → hoof photographs → invoice →
payment status → next appointment

It exists to keep the operational and historical record of farrier work
connected from one visit to the next. Success means a farrier can move through
that cycle quickly in the field without losing context, duplicating records, or
returning to separate administrative tools after the appointment.

## Positioning

FarrierFlow is an iPhone-first business application organized around the actual
sequence of independent farrier work. Horse history, performed work, hoof
photographs, invoicing, payment status, and follow-up scheduling remain parts of
one continuous field workflow rather than separate generic business modules.

## Operating Context

- Used primarily at barns and other outdoor or variable-light environments.
- Operated while standing and frequently with one hand.
- Centers each visit on an appointment, the horse's history, work performed,
  hoof photographs, an invoice, payment status, and the next appointment.
- Serves independent practitioners rather than a general veterinary practice or
  a generic office-based service business.

## Capabilities and Constraints

- The product is iPhone-first and native to iOS.
- It targets iOS 18 and later, with iOS 26 as the primary design and validation
  environment. Current project configuration evidence is recorded below.
- The interface uses SwiftUI, standard Apple controls, and native navigation and
  interaction patterns.
- The interface inherits current platform appearance and materials; it does not
  manually reproduce Liquid Glass.
- Core records must connect appointments, horses and their history, performed
  work, hoof photographs, invoices, payment status, and future appointments.
- Slice 2 records performed work as a Visit started from an existing
  Appointment. Every scheduled horse receives a serviced or not-serviced
  outcome before completion, and serviced horses may include free-text Work
  Notes.
- An in-progress Visit can be saved and resumed. A completed Visit remains
  available from its Appointment and from Horse History.
- Visit history preserves the actual Visit start time and immutable
  service-location name and address snapshots. It does not rewrite history when
  the current service-location record changes.
- Core business records are local-first and must remain usable without a
  network connection. Standard operating-system device backup is permitted;
  FarrierFlow provides no app-managed backup, synchronization, accounts, or
  multi-device behavior.
- Payment status is in scope. Payment processing and external integrations are
  not yet confirmed.
- The application must remain efficient under field conditions and must not
  depend on invented interaction patterns.

## Brand Commitments

- The product name is FarrierFlow.
- Its character is durable, calm, professional, efficient, and field-ready.
- It must not feel western-themed, rustic, veterinary, cartoonish, or like a
  generic SaaS dashboard.
- Distinction should come from a restrained accent palette, field-specific copy,
  excellent hierarchy, horse photography, careful spacing, strong empty states,
  and subtle haptics.
- Preserve native platform behavior. Avoid custom navigation, custom tab bars,
  glass cards, gradients, excessive corner radii, card-on-card layouts,
  decorative icons, oversized headings, and invented interaction patterns.

## Evidence on Hand

- The repository contains the iPhone-only SwiftUI and SwiftData implementation
  through Slice 3 in `FarrierFlow/`.
- The Xcode project declares iOS 18.0 for the app, unit-test, and UI-test
  targets and includes iPhone device support.
- The approved Slice 2 design is recorded in
  `docs/superpowers/specs/2026-07-27-slice-2-visit-completion-design.md`.
- The approved Slice 3 design is recorded in
  `docs/superpowers/specs/2026-07-28-slice-3-hoof-photographs-design.md`.
- No bundled customer imagery, logo, customer evidence, testimonials, pricing,
  integrations, or operational sample data is currently present in the
  repository. Future work must not fabricate these.

## Product Principles

1. Follow the farrier's real service sequence from appointment through the next
   visit.
2. Make the next necessary action obvious and quick while preserving horse and
   visit history.
3. Prefer trusted native iOS behavior over custom interface invention.
4. Design for field use first: outdoor legibility, one-handed operation, and
   efficient capture while standing.
5. Keep the product professional and specific to farrier work without resorting
   to themed decoration or generic business-software patterns.

## Accessibility & Inclusion

- Support Dynamic Type without truncating, clipping, or obscuring primary
  actions.
- Provide complete, meaningful VoiceOver labels, values, hints, grouping, and
  reading order.
- Maintain outdoor readability through strong contrast, clear hierarchy, and
  reliance on semantic system colors.
- Keep interactive targets at least 44 × 44 points and place frequent actions
  within comfortable one-handed reach.
- Respect system accessibility settings, including Increased Contrast and Reduce
  Motion, and treat Dark Mode as a first-class platform appearance.
