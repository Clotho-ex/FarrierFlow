# Analytics Contract

FarrierFlow analytics describe meaningful application state transitions. They
must never become a second copy of the farrier's local business records.
Feature code tracks the closed `AnalyticsEvent` enum through
`AnalyticsClient`; it does not call an analytics provider directly. Production,
previews, and UI tests currently use `NoOpAnalyticsClient`, which does not log,
persist, identify, or transmit anything.

Provider-facing names are stable lowercase snake case and are translated by
`AnalyticsProviderEvent`. They are not members of the feature-facing
`AnalyticsEvent` API.

## Event catalog

| Event | Allowed properties | Runtime status |
| --- | --- | --- |
| `app_first_opened` | None | Deferred |
| `app_session_started` | None | Deferred pending session semantics |
| `onboarding_started` | None | Wired at the fresh persisted onboarding transition |
| `onboarding_briefing_completed` | None | Contract only |
| `business_setup_completed` | None | Contract only |
| `onboarding_completed` | None | Wired after the completion marker is written |
| `paywall_viewed` | None | Contract only |
| `subscription_plan_selected` | `plan`: `monthly` or `annual` | Contract only |
| `subscription_purchase_started` | `plan`: `monthly` or `annual` | Contract only |
| `subscription_purchase_completed` | `plan`: `monthly` or `annual` | Contract only |
| `subscription_purchase_cancelled` | `plan`: `monthly` or `annual` | Contract only |
| `subscription_restore_completed` | None | Contract only |
| `client_created` | None | Contract only |
| `horse_created` | None | Contract only |
| `service_created` | None | Contract only |
| `service_location_created` | None | Contract only |
| `appointment_created` | None | Wired after a new appointment persists |
| `visit_started` | None | Contract only |
| `visit_completed` | None | Wired after visit completion succeeds |
| `invoice_created` | None | Wired after atomic invoice generation succeeds |
| `invoice_shared` | None | Contract only |
| `invoice_marked_paid` | None | Contract only |
| `next_appointment_created` | None | Contract only |

The only current property type is the closed monthly/annual subscription-plan
enum. There is no free-form event-name, property-key, property-value, or
dictionary API. Feature code submits only `AnalyticsEvent`; a future provider
will consume `AnalyticsProviderEvent` inside its adapter.

## Forbidden data

Analytics must never receive customer or business-record contents, including:

- client, horse, owner, business, or service-location names;
- phone numbers, email addresses, street or service-location addresses;
- work notes, invoice notes or descriptions, or any user-entered text;
- invoice PDFs, photographs, filenames, file paths, or photo metadata;
- bank, card, payment, invoice-value, customer-value, or exact business-count data;
- SwiftData persistent identifiers, invoice/customer identifiers, RevenueCat
  customer identifiers, or newly generated identifiers;
- device information or any other personally identifiable information.

## Emission rules

Events represent business truth, not taps or rendering. Creation and completion
events fire only after the corresponding operation succeeds. Failed operations,
record edits, corrections, retries, SwiftUI reconstruction, `.task`,
`onAppear`, and navigation visits must not report successful transitions.

`onboarding_started` is emitted only when the onboarding model moves from a
fresh unresolved state into its persisted briefing state. Resolving that state
again, reconstructing the UI, resuming an interrupted onboarding, or bypassing
onboarding for an existing workspace does not emit it again.

`visit_completed` follows the persisted `completedAt` transition; a reopened
completed visit is correction-only. `invoice_created` follows atomic invoice
generation; persisted invoice-line links make the same work ineligible after
model reconstruction or relaunch.

## Future provider boundary

PostHog or another provider may later implement `AnalyticsClient`. Provider
integration, remaining event wiring, RevenueCat and Apple Ads attribution,
rating prompts, and dashboards are separate units and are not implemented here.
