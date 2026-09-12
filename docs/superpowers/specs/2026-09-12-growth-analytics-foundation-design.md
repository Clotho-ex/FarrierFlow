# FarrierFlow Growth Analytics Foundation Design

## Scope

FarrierFlow will own a small typed analytics boundary for the first post-launch
release. Feature code will depend only on `AnalyticsClient` and
`AnalyticsEvent`. The production default is a no-op client. No analytics SDK,
networking, identifier generation, persistence, attribution, or release action
is part of this unit.

## Contract

`AnalyticsEvent` is a closed `Sendable` enum. A separate provider
representation gives every case one stable lowercase snake-case name without
exposing those names on the feature-facing event API. Only subscription
selection and purchase events carry a property, and that property is the closed
`AnalyticsSubscriptionPlan` enum (`monthly` or `annual`). Generated properties
are typed values; feature code cannot supply event names, property keys,
property values, dictionaries, or arbitrary strings.

The catalog covers first open, application session start, onboarding,
subscription funnel, and the core activation transitions. First-open and
session-start runtime semantics remain deliberately unwired until their
lifecycle rules are designed.

## Dependency and data flow

`AnalyticsClient` and the event contract import no UI or provider framework.
They remain directly injectable into model and use-case boundaries. A separate
SwiftUI environment extension provides convenient access and defaults to
`NoOpAnalyticsClient`; app composition explicitly supplies the same no-op
implementation for production and UI-test configurations.

Representative views pass the environment client into their model mutation
methods. Models emit only after their persistence/completion operation succeeds:

- onboarding starts when the onboarding model durably transitions from an
  unresolved fresh state into the briefing state;
- onboarding completes after its completion marker is written;
- a new appointment emits after graph validation and persistence succeed;
- a visit emits after the completion use case succeeds;
- an invoice emits after atomic invoice generation succeeds.

Restored onboarding state, existing configured workspaces, existing-record
edits, failed saves, failed completion, SwiftUI reconstruction, and repeated
resolution do not emit those events.

## Privacy boundary

The public tracking API accepts only an `AnalyticsEvent`. It has no generic
string event API and no dictionary property API. No case accepts business
records, persistent identifiers, names, contact information, addresses, notes,
invoice values, payment details, photographs, file metadata, RevenueCat IDs,
device information, or arbitrary user-entered text.

## Verification

Swift Testing coverage verifies the full name catalog, plan-property mapping,
property allowlist, no-op acceptance, deterministic onboarding transitions,
success-only representative instrumentation, and no double firing. Validation
also includes directly affected suites, the broader unit/integration target, an
iOS Simulator app build, static dependency/network scans, and a final diff
review.
