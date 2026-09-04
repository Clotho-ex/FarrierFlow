# FarrierFlow Color Palette Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Introduce and apply the approved warm, semantic FarrierFlow palette centered on `#BF5700`.

**Architecture:** Expand the existing `ColorTokens` boundary with trait-aware semantic tokens, keep native SwiftUI component behavior, and add only reusable surface and status treatments with multiple real consumers. Feature views select colors by meaning rather than literals.

**Tech Stack:** Swift 6, SwiftUI, UIKit dynamic colors, Swift Testing, XCUITest, Asset Catalogs

**Spec:** `docs/superpowers/specs/2026-09-03-color-palette-revamp-design.md`

## Global Constraints

- Preserve existing layout, routing, persistence, subscription, pricing, and read-only behavior.
- Preserve all pre-existing uncommitted work and do not commit or push.
- Use `#BF5700` as the Light Mode action color and `#E06C12` in Dark Mode.
- Keep orange scarce and semantic; retain native pressed and disabled behavior.
- Verify serially on one simulator with parallel testing disabled.

---

### Task 1: Semantic palette contract

**Files:**
- Modify: `FarrierFlow/Core/DesignSystem/ColorTokens.swift`
- Create: `FarrierFlowTests/Core/DesignSystem/ColorTokensTests.swift`
- Modify: `FarrierFlow/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Modify: `FarrierFlow/Resources/Assets.xcassets/FarrierFlowLaunchBackground.colorset/Contents.json`

**Interfaces:**
- Produces: semantic `ColorTokens` properties and a trait-aware internal resolver.

- [x] Write tests that resolve representative tokens in Light, Dark, and Increased Contrast traits and assert hand-derived RGB values.
- [x] Run the focused test and verify it fails because the semantic contract is absent.
- [x] Implement the minimal token resolver and approved palette.
- [x] Update the platform accent and launch background assets.
- [x] Re-run the focused test and verify it passes.

### Task 2: Shared surface and status presentation

**Files:**
- Create: `FarrierFlow/Core/DesignSystem/FarrierFlowSurface.swift`
- Create: `FarrierFlow/Core/DesignSystem/StatusBadge.swift`
- Extend: `FarrierFlowTests/Core/DesignSystem/ColorTokensTests.swift` for contrast pairings.

**Interfaces:**
- Consumes: `ColorTokens`.
- Produces: `farrierFlowScreenBackground()`, `farrierFlowScrollBackground()`, `StatusTone`, and `StatusBadge`.

- [x] Write failing color-resolution and action-label contrast tests; verify semantic statuses through affected UI journeys.
- [x] Implement the smallest shared presentation types.
- [x] Run focused design-system tests and verify they pass.

### Task 3: App shell, onboarding, and primary-action migration

**Files:**
- Modify: `FarrierFlow/App/FarrierFlowApp.swift`
- Modify: `FarrierFlow/App/RootView.swift`
- Modify: `FarrierFlow/Features/Onboarding/Views/OnboardingFlowView.swift`
- Modify: `FarrierFlow/Features/Onboarding/Views/OnboardingScreenComponents.swift`
- Modify: `FarrierFlow/Features/BusinessProfile/Views/BusinessProfileEditorView.swift`
- Modify: `FarrierFlow/Features/Subscription/Views/SubscriptionView.swift`
- Modify: `FarrierFlow/Features/Today/Views/TodayView.swift`
- Modify: launch and in-app mark SVGs under `FarrierFlow/Resources/Assets.xcassets/`.

**Interfaces:**
- Consumes: semantic tokens and surface modifiers from Tasks 1-2.

- [x] Apply the root tint and warm screen environment.
- [x] Replace onboarding-specific and Survey Ink tokens with semantic roles.
- [x] Convert the Today action band to a quiet tinted action surface.
- [x] Preserve native primary-button styles and existing accessibility behavior.
- [x] Run focused onboarding and Today UI checks.

### Task 4: Operational screen and status migration

**Files:**
- Modify: directly affected List/Form roots under `FarrierFlow/Features/`.
- Modify: `AppointmentRow.swift`, `AppointmentDetailView.swift`, `HorseSelectionRow.swift`, `InvoiceRow.swift`, `InvoiceDetailView.swift`, `InvoiceVisitSelectionRow.swift`, `ServiceEditorView.swift`, and `WorkItemEditorView.swift`.

**Interfaces:**
- Consumes: semantic tokens, surface modifiers, and `StatusBadge`.

- [x] Apply warm canvases to operational List/Form screens without replacing native controls or bar materials.
- [x] Map appointment and invoice statuses to neutral, active, success, and warning tones.
- [x] Map safety attention to warning and custom destructive text to destructive.
- [x] Keep full-screen photograph controls white for contrast.
- [x] Run focused appointment, invoice/payment, visit, editor, and read-only UI checks.

### Task 5: Documentation and final verification

**Files:**
- Modify: `DESIGN.md`
- Modify: `ARCHITECTURE.md`
- Modify: `ROADMAP.md`
- Modify: `.agents/workflow/CURRENT_UNIT.md`

**Interfaces:**
- Consumes: the completed palette implementation and verified behavior.

- [x] Replace obsolete Survey Ink documentation with the approved semantic hierarchy.
- [x] Run focused design-system tests and affected UI suites serially.
- [x] Build on iOS 18 and iOS 26.
- [x] Validate asset JSON/SVG and run `git diff --check`.
- [x] Inspect representative simulator screens in Light, Dark, Increased Contrast, and accessibility text size.
- [x] Review the final diff and clean up task-owned simulator/test processes.

## Verification record

- iOS 26.5: six design-token tests and twelve UI tests passed in `Test-FarrierFlow-2026.09.03_21-54-30-+0300.xcresult`. UI coverage includes both onboarding appearances, accessibility XXXL, Today, invoice/payment persistence, and full-screen photograph metadata.
- iOS 18.0: six final design-token tests passed in `Test-FarrierFlow-2026.09.03_21-53-23-+0300.xcresult`. Four operational UI journeys (editor accessibility, onboarding, read-only access, visit completion) and a separate dark onboarding visual journey also passed in the preceding compatibility runs.
- Contrast tests cover primary button labels, action text on selected surfaces, primary/secondary information, and opaque success badges. Native UIKit providers and actual SwiftUI appearance resolution are tested separately, avoiding iOS 18's lossy `Color`-to-`UIColor` conversion.
- Review found and corrected low-contrast dark action text and translucent success tints. Simulator testing found and corrected main-actor isolation in dynamic UIKit color providers; a background-renderer regression now covers this. One stale incremental simulator build crashed during startup; a clean rebuild of frozen source resolved it and all affected UI journeys passed.
- Final screenshot review found a neutral inline destructive label. Explicit destructive styling was added to inline invoice, work-item, photo, and toolbar controls; native dialog/menu roles remain intact. All three invoice/photo tests passed again in `Test-FarrierFlow-2026.09.03_22-02-28-+0300.xcresult`, and the final iOS 18 build passed. The corrected red inline action and orange primary action were visually verified together.
- Asset JSON parsing, SVG XML validation, string-catalog compilation dry run, and whitespace checks passed. Existing unrelated onboarding/subscription changes remain untouched by this palette unit; no commit, push, dependency, release, billing, or production-data operation was performed.
- Final manual review covered Light/Dark onboarding, Today, invoice warning/action/destructive treatments, Increased Contrast, and accessibility XXXL. Native dialogs retained their red destructive role. Simulator settings were restored to Light, standard contrast, and Large text. The updated iOS 26.5 app is intentionally left visible with the isolated `PaletteReview-Final` test fixture; build/test runners and runtime log streams are stopped.
