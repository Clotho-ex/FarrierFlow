# FarrierFlow Growth Analytics Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add FarrierFlow's provider-independent, typed, privacy-safe analytics contract and prove it with a small set of deterministic success-boundary events.

**Architecture:** A SwiftUI-independent `AnalyticsClient` consumes a closed `AnalyticsEvent` enum whose only property-bearing cases use a monthly/annual enum. SwiftUI supplies convenient environment access to the no-op dependency, while feature models receive the client explicitly at mutation boundaries and emit only after successful state transitions.

**Tech Stack:** Swift 6, SwiftUI environment values, SwiftData feature models, Swift Testing, Xcode 26.6.

**Spec:** `docs/superpowers/specs/2026-09-12-growth-analytics-foundation-design.md`

## Global Constraints

- Base all work on `v1.0-review-submitted` without modifying `main` or App Store state.
- Add no SDK, networking, persistence, identifier, RevenueCat, Apple Ads, review-prompt, dashboard, or release behavior.
- Accept no arbitrary event names, property dictionaries, identifiers, or user-entered strings.
- Keep `AnalyticsClient` and `AnalyticsEvent` independent of SwiftUI.
- Emit `onboarding_started` only from a deterministic persisted onboarding transition.

---

### Task 1: Typed analytics contract

**Files:**
- Create: `FarrierFlow/Core/Analytics/AnalyticsEvent.swift`
- Create: `FarrierFlow/Core/Analytics/AnalyticsClient.swift`
- Create: `FarrierFlowTests/Core/Analytics/AnalyticsContractTests.swift`

**Interfaces:**
- Produces: `AnalyticsClient.track(_:)`, `NoOpAnalyticsClient`, `AnalyticsEvent`, `AnalyticsSubscriptionPlan`, and typed generated properties.

- [x] Write catalog tests enumerating every approved case, expected provider name, and expected typed properties.
- [x] Run `AnalyticsContractTests` and confirm compilation fails because the contract does not exist.
- [x] Implement the closed enums, deterministic mapping, protocol, and no-op client.
- [x] Rerun `AnalyticsContractTests` and confirm it passes.

### Task 2: Deterministic onboarding instrumentation

**Files:**
- Modify: `FarrierFlow/Features/Onboarding/OnboardingExperienceModel.swift`
- Modify: `FarrierFlow/App/RootView.swift`
- Test: `FarrierFlowTests/Features/Onboarding/OnboardingExperienceModelTests.swift`

**Interfaces:**
- Consumes: `AnalyticsClient.track(_:)`.
- Produces: injectable `resolve(..., analyticsClient:)`, `businessSetupDidFinish(..., analyticsClient:)`, and `subscriptionAccessDidChange(_:analyticsClient:)` behavior.

- [x] Add tests showing fresh unresolved onboarding emits once, reconstruction/resolution does not re-emit, compatibility bypass does not emit, and genuine completion emits once.
- [x] Run the onboarding suite and confirm the new assertions fail.
- [x] Inject the client into model transition methods and pass the environment dependency from `RootView`.
- [x] Rerun the onboarding suite and confirm it passes.

### Task 3: Success-boundary activation events

**Files:**
- Modify: `FarrierFlow/Features/Schedule/AppointmentEditorModel.swift`
- Modify: `FarrierFlow/Features/Schedule/Views/AppointmentEditorView.swift`
- Modify: `FarrierFlow/Features/Visits/VisitEditorModel.swift`
- Modify: `FarrierFlow/Features/Visits/Views/VisitEditorView.swift`
- Modify: `FarrierFlow/Features/Invoices/InvoiceCreationModel.swift`
- Modify: `FarrierFlow/Features/Invoices/Views/InvoiceCreationView.swift`
- Test: `FarrierFlowTests/Features/Schedule/AppointmentEditorModelTests.swift`
- Test: `FarrierFlowTests/Features/Visits/VisitEditorModelTests.swift`
- Test: `FarrierFlowTests/Features/Invoices/InvoiceCreationModelTests.swift`

**Interfaces:**
- Consumes: explicit `any AnalyticsClient` arguments supplied by thin SwiftUI call sites.
- Produces: success-only `appointment_created`, `visit_completed`, and `invoice_created` emissions.

- [x] Add tests for success, failure, edit/correction exclusion, and repeated-call behavior.
- [x] Run the three affected suites and confirm the new assertions fail.
- [x] Add minimal client arguments and emit after successful domain operations only.
- [x] Rerun the three affected suites and confirm they pass.

### Task 4: SwiftUI access and documentation

**Files:**
- Create: `FarrierFlow/Core/Analytics/AnalyticsEnvironment.swift`
- Modify: `FarrierFlow/App/FarrierFlowApp.swift`
- Create: `docs/analytics.md`

**Interfaces:**
- Consumes: the SwiftUI-independent analytics contract.
- Produces: `EnvironmentValues.analyticsClient` with a no-op default and explicit app composition.

- [x] Add the environment access layer without adding SwiftUI imports to the contract files.
- [x] Document purpose, naming, catalog, allowed properties, forbidden data, representative wiring, and deferred provider work.
- [x] Run focused analytics and affected feature tests.

### Task 5: Final validation and review

**Files:**
- Review all changed paths only.

- [x] Run the complete `FarrierFlowTests` target serially on iOS 18.0 and iOS 26.5.
- [x] Build the `FarrierFlow` app target for both simulators.
- [x] Run `git diff --check` and inspect `git diff --stat` plus the complete diff.
- [x] Scan the dependency graph and source for analytics SDKs, network requests, unrestricted analytics dictionaries, identifiers, and business-record values.
- [x] Verify `main` and `v1.0-review-submitted` remain at `517d4d5` and no release or portal operation occurred.
