# Growth Analytics Unit 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a privacy-first PostHog provider behind FarrierFlow's Unit 1 analytics contract and wire the remaining truthful high-value funnel events.

**Architecture:** Feature and model code continues to accept only `AnalyticsEvent` through `AnalyticsClient`. Application composition validates centralized Info.plist configuration and selects either a no-op client or a small PostHog adapter; only that adapter imports PostHog and converts the closed provider representation to SDK properties. Business mutations remain authoritative and emit only after persistence succeeds.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, Xcode 26, iOS 18+, PostHog iOS SDK 3.74.0 through Swift Package Manager.

**Spec:** User-provided “FarrierFlow Growth Instrumentation — Unit 2” brief; Unit 1 contract in `docs/analytics.md`.

## Global Constraints

- Work only on `growth/v1.0.1-analytics` at Unit 1 commit `0875be0a25b206e638bbd9014f3b31897b0861aa`.
- Leave `main`, `origin/main`, and `v1.0-review-submitted` at `517d4d5b59dfb66a1151e94e4946a6359e436fd7`.
- Preserve the closed `AnalyticsEvent` and `AnalyticsClient` boundary; no feature-facing names, dictionaries, strings, IDs, or business records.
- Disable PostHog lifecycle, screen, element, replay, feature-flag, survey, push, error, log, profile, and identification behavior wherever the SDK supports it.
- Keep previews and UI tests on `NoOpAnalyticsClient`.
- Do not modify RevenueCat behavior, App Store state, public website, PostHog dashboard, or Apple attribution.
- Do not commit or push until the event/privacy diff review is approved.

---

### Task 1: Provider dependency, configuration, and translation

**Files:**
- Modify: `FarrierFlow.xcodeproj/project.pbxproj`
- Modify: `FarrierFlow.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Modify: `FarrierFlow/Info.plist`
- Create: `FarrierFlow/Core/Analytics/PostHogAnalyticsConfiguration.swift`
- Create: `FarrierFlow/Core/Analytics/PostHogAnalyticsClient.swift`
- Modify: `FarrierFlow/App/FarrierFlowApp.swift`
- Create: `FarrierFlowTests/Core/Analytics/PostHogAnalyticsTests.swift`

**Interfaces:**
- Consumes: `AnalyticsClient.track(_:)` and `AnalyticsProviderEvent.init(_:)`.
- Produces: validated `PostHogAnalyticsConfiguration`, testable composition selection, and `PostHogAnalyticsClient` capture translation.

- [ ] Write failing configuration, provider-selection, SDK-option, and capture-translation tests.
- [ ] Run only `PostHogAnalyticsTests` and confirm failures are caused by missing Unit 2 types.
- [ ] Add PostHog 3.74.0, ignored local/release token configuration, centralized token/host Info.plist substitutions, safe no-op fallback, and non-sensitive DEBUG diagnostics.
- [ ] Configure the SDK with person profiles, lifecycle/screen/element capture, replay, surveys, push hooks, feature-flag preload/events/default person properties, and error capture disabled; keep SDK debug off.
- [ ] Run `PostHogAnalyticsTests` and `AnalyticsContractTests` until green.

### Task 2: Deterministic onboarding and subscription funnel

**Files:**
- Modify: `FarrierFlow/Features/Onboarding/OnboardingExperienceModel.swift`
- Modify: `FarrierFlow/Features/Onboarding/Views/OnboardingFlowView.swift`
- Modify: `FarrierFlow/Features/Subscription/SubscriptionAccessModel.swift`
- Modify: `FarrierFlow/Features/Subscription/Views/SubscriptionView.swift`
- Create: `FarrierFlow/Features/Subscription/OnboardingSubscriptionSelectionModel.swift`
- Modify: `FarrierFlowTests/Features/Onboarding/OnboardingExperienceModelTests.swift`
- Modify: `FarrierFlowTests/Features/Subscription/SubscriptionAccessModelTests.swift`
- Create: `FarrierFlowTests/Features/Subscription/OnboardingSubscriptionSelectionModelTests.swift`

**Interfaces:**
- Consumes: existing persisted onboarding steps and RevenueCat-derived `SubscriptionPurchaseResult`.
- Produces: briefing, initial business setup, onboarding paywall exposure, explicit plan selection, purchase outcome, and restore events.

- [ ] Write failing tests for each persisted onboarding transition, relaunch/reconstruction non-duplication, programmatic default selection silence, explicit selection, purchase success/cancellation/failure, and restore success/failure.
- [ ] Run the onboarding/subscription test classes and confirm expected failures.
- [ ] Emit onboarding events only after persisted step changes and subscription events only around the existing client operation and authoritative returned entitlement state.
- [ ] Pass the environment client into model actions without importing SwiftUI into analytics domain files.
- [ ] Run the focused onboarding/subscription tests until green.

### Task 3: Persisted creation, visit, payment, next-appointment, and share events

**Files:**
- Modify: `FarrierFlow/Features/Clients/ClientEditorModel.swift`
- Modify: `FarrierFlow/Features/Clients/Views/ClientEditorView.swift`
- Modify: `FarrierFlow/Features/Horses/HorseEditorModel.swift`
- Modify: `FarrierFlow/Features/Horses/Views/HorseEditorView.swift`
- Modify: `FarrierFlow/Features/Services/ServiceEditorModel.swift`
- Modify: `FarrierFlow/Features/Services/Views/ServiceEditorView.swift`
- Modify: `FarrierFlow/Features/Barns/BarnEditorModel.swift`
- Modify: `FarrierFlow/Features/Barns/Views/BarnEditorView.swift`
- Modify: `FarrierFlow/Features/Visits/VisitStartUseCase.swift`
- Modify: `FarrierFlow/Features/Schedule/AppointmentDetailModel.swift`
- Modify: `FarrierFlow/Features/Schedule/Views/AppointmentDetailView.swift`
- Modify: `FarrierFlow/Features/Schedule/AppointmentEditorModel.swift`
- Modify: `FarrierFlow/Features/Invoices/PaymentRecordingModel.swift`
- Modify: `FarrierFlow/Features/Invoices/Views/InvoiceDetailView.swift`
- Modify: `FarrierFlow/Features/Invoices/Views/InvoiceShareSheet.swift`
- Modify: directly corresponding model/use-case test files.

**Interfaces:**
- Consumes: each feature's existing successful persistence boundary and `NextAppointmentSeed` provenance.
- Produces: creation, visit-start, paid, assisted-next-appointment, and completed-share events with no record properties.

- [ ] Write failing tests proving create-only, persistence-after-success, edit/reconstruction silence, visit-start idempotence, paid transition truth, assisted appointment creation, and share completion/cancellation semantics.
- [ ] Run each directly affected test class and confirm expected failures.
- [ ] Add analytics parameters with no-op defaults and emit after the existing successful save/result boundary only.
- [ ] Route SwiftUI environment access into those injectable methods and keep views free of provider imports.
- [ ] Run all directly affected tests until green.

### Task 4: Privacy documentation and validation

**Files:**
- Modify: `docs/analytics.md`

**Interfaces:**
- Consumes: final PostHog 3.74.0 source audit and complete wired-event diff.
- Produces: provider settings, automatic-property inventory, anonymous-ID behavior, disclosure checklist, privacy-policy follow-up, and deferred catalog.

- [ ] Document every wired/contract-only event and its exact emission boundary.
- [ ] Document SDK-owned UUIDv7 anonymous/device IDs, session ID, automatic app/device/locale/network properties, queue persistence, host, bundled privacy manifest, unavoidable remote-config request, provider-level GeoIP-disable processing control, and owner-side GeoIP confirmation.
- [ ] Run focused provider/configuration/event tests and every directly affected model test.
- [ ] Run the complete `FarrierFlowTests` target on the primary iOS 26 simulator and validate an iOS 18 build.
- [ ] Run `git diff --check`, package/project inspection, forbidden-API/import/property searches, and frozen-release SHA checks.
- [ ] Stop task-owned simulator/build/test processes and return the uncommitted diff classification for event/privacy review.
