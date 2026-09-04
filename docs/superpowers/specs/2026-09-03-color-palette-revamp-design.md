# FarrierFlow Color Palette Revamp Design

## Goal

Replace the existing Survey Ink visual accent with a restrained semantic color
system centered on `#BF5700`, while preserving FarrierFlow's native Field Book
layout, behavior, accessibility, and local-first product boundaries.

## Architecture

`ColorTokens` remains the only source-code entry point for application colors.
It exposes role-based dynamic colors for brand, neutral surfaces and text, and
semantic success, warning, destructive, and information states. Raw RGB values
exist only inside that design-system boundary and in platform assets that must
resolve before SwiftUI starts, such as the global accent and launch screen.

The token resolver selects Light or Dark Mode values from the approved palette.
In Increased Contrast, it strengthens brand, muted text, and
borders using only stronger values already present in the approved palette.
Small action text uses contrast-safe brand shades independently of button fills.
Primary buttons retain native geometry and pressed/disabled surfaces, with
appearance- and enabled-state-aware label colors. Dynamic providers are
nonisolated and capture immutable values for SwiftUI's asynchronous renderer.
Dark semantic tints are opaque to keep contrast independent of the parent fill.
Feature code continues to use native SwiftUI controls and materials where they
provide interaction behavior that a static custom color cannot improve.

## Application Rules

- Orange identifies primary actions, current selection, active progress, and
  focused controls. It is not used for passive metadata, ordinary icons, card
  borders, or large decorative backgrounds.
- Screen canvases use the warm background token. Custom grouped surfaces use
  surface or elevated surface tokens; native sheets, bars, alerts, and controls
  retain system-owned material behavior.
- Paid and completed states use success green; due and safety-attention states
  use warning amber; failed and destructive states use red; neutral system
  information uses blue-gray only when it has genuine informational meaning.
- Important state remains paired with text and, where appropriate, an SF Symbol
  or native control state. Color is never the only carrier.
- The Today promoted action changes from a saturated full-band fill to a quiet
  brand-tinted surface with a precise orange action treatment.
- Onboarding and Subscription use the same background, surface, selection, and
  action tokens as the rest of the app. The launch mark may use orange as the
  product identity; the launch canvas uses the normal app background.
- Full-screen photograph controls may retain white when image-independent
  contrast requires it.
- Invoice PDF colors remain document-specific because a printed PDF has no
  Light/Dark appearance and is outside the app chrome palette.

## Components

Add a small reusable semantic status treatment for labels that already display
status in Appointment and Invoice surfaces. Its tones are neutral, active,
success, warning, destructive, and information. Each presentation includes
status text and may include a symbol, with a tinted background used only for
compact status labels.

Add narrowly scoped background modifiers for scroll-backed app screens. They
hide the default scroll canvas and reveal the warm app background without
replacing native navigation, tab, toolbar, sheet, form-control, or alert
behavior.

## Compatibility and Accessibility

The implementation targets iOS 18 and the current iOS 26 SDK. Dynamic colors
resolve through `UITraitCollection`, including Dark Mode and Increased
Contrast. Native disabled and pressed states remain system controlled. Dynamic
Type layouts and existing accessibility labels, values, identifiers, and
reading order remain unchanged unless a status symbol needs to be marked
decorative.

## Verification

Use test-first coverage for the palette resolver and text contrast pairings.
Run the focused design-system tests, affected UI journeys, iOS 18 and iOS 26
builds, asset validation, and `git diff --check`. Inspect representative
screens in the simulator in Light Mode, Dark Mode, Increased Contrast, and an
accessibility text size, including onboarding, Today, an appointment warning,
paid and unpaid invoices, a form/list surface, and photography controls.

## Scope Boundaries

No persistence, subscription, payment, routing, pricing, copy, layout-system,
or third-party dependency changes are part of this work. Existing uncommitted
onboarding and RevenueCat changes remain intact. No commit, push, archive,
upload, deployment, or App Store mutation is authorized.
