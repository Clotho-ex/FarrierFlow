# Analytics Contract

FarrierFlow analytics describe meaningful application state transitions. They
must never become a second copy of the farrier's local business records.
Feature and model code track the closed `AnalyticsEvent` enum through
`AnalyticsClient`; only `PostHogAnalyticsClient` imports PostHog or translates
events into provider names and dictionaries.

PostHog iOS 3.74.0 is the production provider. Previews use the SwiftUI
environment's no-op default, UI tests explicitly compose
`NoOpAnalyticsClient`, and missing or malformed production configuration also
fails safely to the no-op client. DEBUG builds log only a configuration error
category; they never log the project token, anonymous ID, event, or payload.

## Provider configuration

`PostHogProjectToken` and `PostHogHost` are application-owned Info.plist keys
populated by `POSTHOG_PROJECT_TOKEN` and `POSTHOG_HOST` build settings. The
tracked `Configuration/PostHog.xcconfig` deliberately leaves the token empty and
optionally includes the ignored `Configuration/PostHog.local.xcconfig`. Local
developers may define `POSTHOG_PROJECT_TOKEN` there; release automation may
provide the same build setting through its protected environment. Never commit
the real token. An absent token reaches the existing validation boundary and
selects `NoOpAnalyticsClient`. The host must be an HTTPS origin and the token
must have the expected public project-token format. The tracked ingestion origin
for this project is `https://us.i.posthog.com`.

The provider explicitly sets:

| Capability | Configuration |
| --- | --- |
| Application lifecycle autocapture | Disabled |
| Automatic screen views and manual screen calls | Disabled / not used |
| Element interaction autocapture | Disabled |
| SDK swizzling | Disabled |
| Push-subscription and push-open capture | Disabled |
| Session replay, screenshots, network replay, replay logs | Disabled |
| Feature-flag preload and feature-flag events | Disabled |
| Surveys | Disabled |
| Error/crash autocapture | Disabled |
| Rage-click capture | Disabled |
| Person-profile defaults | Disabled |
| Person profiles | `never` |
| Identify, alias, groups, super-properties, person properties | Not used |
| PostHog debug logging | Disabled in Debug and Release |

PostHog 3.74.0 always fetches its token-scoped remote configuration endpoint
during SDK setup; its public iOS configuration has no production switch to
disable that fetch. Disabling feature-flag preload prevents the follow-up flags
request and FarrierFlow does not evaluate flags or use remote configuration for
product behavior.

## Event catalog

Stable provider names use lowercase snake case. The only feature-authored
property is the closed `plan` value (`monthly` or `annual`) on the four listed
subscription events. Inside the private provider translation layer, every
capture also receives the fixed processing control `$geoip_disable = true`.
Feature code cannot inspect, change, or add provider properties.
PostHog's current stable GeoIP transformation returns before lookup when this
property is true. PostHog iOS does not yet expose a dedicated `disableGeoip`
configuration option, so FarrierFlow supplies the documented ingestion
property inside its provider adapter.

| Provider event | Allowed properties | Status and exact emission boundary |
| --- | --- | --- |
| `app_first_opened` | None | Contract only; runtime semantics deferred |
| `app_session_started` | None | Contract only; runtime semantics deferred |
| `onboarding_started` | None | Wired after fresh onboarding persists the briefing state |
| `onboarding_briefing_completed` | None | Wired after the briefing transition persists the business-setup state |
| `business_setup_completed` | None | Wired once after initial onboarding business setup advances successfully; profile edits do not emit |
| `onboarding_completed` | None | Wired after the onboarding completion version is persisted |
| `paywall_viewed` | None | Wired once when onboarding persists its transition into the subscription state; no view-lifecycle emission |
| `subscription_plan_selected` | `plan` | Wired for a user's actual change of the onboarding selection; default annual reconciliation is silent |
| `subscription_purchase_started` | `plan` | Wired immediately before calling the existing subscription client for a validated plan |
| `subscription_purchase_completed` | `plan` | Wired only when a non-cancelled result contains active Pro entitlement truth |
| `subscription_purchase_cancelled` | `plan` | Wired only when the subscription client explicitly reports user cancellation |
| `subscription_restore_completed` | None | Wired after the restore request returns successfully, regardless of whether its returned entitlement is active |
| `client_created` | None | Wired after a new Client persists; edits and failures do not emit |
| `horse_created` | None | Wired after a new Horse persists; edits and failures do not emit |
| `service_created` | None | Wired after a new Service persists; edits and failures do not emit |
| `service_location_created` | None | Wired after a new Service Location persists; edits and failures do not emit |
| `appointment_created` | None | Wired after every new Appointment persists |
| `visit_started` | None | Wired after a Visit is created and persisted from an Appointment; an Appointment with a Visit cannot emit again |
| `visit_completed` | None | Wired after the persisted `completedAt` transition; corrections to completed Visits do not emit |
| `invoice_created` | None | Wired after atomic invoice generation succeeds; persisted invoice-work links prevent duplicate creation from reconstructed models |
| `invoice_shared` | None | Wired only when `UIActivityViewController` reports a completed activity; opening or cancelling the sheet does not emit |
| `invoice_marked_paid` | None | Wired after payment evidence and Paid status persist; Paid to Unpaid to Paid is a new truthful transition |
| `next_appointment_created` | None | Wired after a seeded next-appointment assistance flow persists its new Appointment; the generic creation event also emits |

Onboarding briefing, business-setup, and paywall exposure use versioned
onboarding-state markers. The marker is written only after the corresponding
navigation/business transition persists and before analytics is attempted, so
back navigation, relaunch, and model or NavigationStack reconstruction cannot
double-fire the transition.

Analytics remains observational. A business operation succeeds first; an
analytics call is then made synchronously to the SDK's enqueue API. FarrierFlow
does not await uploads, retry events from feature models, or condition business
success on analytics delivery.

## Privacy boundary

The public application contract has no free-form event-name method, arbitrary
property dictionary, or arbitrary-string event property. Provider translation
is private to the PostHog adapter. The compiler therefore prevents feature code
from adding business-record fields to analytics events.

FarrierFlow business-record contents are never sent to PostHog. Forbidden data
includes client, horse, owner, business, service, and location names; phone
numbers and email or street addresses; work, safety, invoice, payment, or other
free text; prices, invoice totals, exact counts, payment methods or payment
details; photographs, PDFs, filenames, paths, and EXIF; SwiftData identifiers;
invoice, customer, RevenueCat, or business identifiers; bank/card data; and all
other user-entered record values.

This is distinct from anonymous product-usage telemetry. PostHog owns and
persists an anonymous UUIDv7 in the app's Application Support container and
uses it as the anonymous distinct/device ID across sessions. FarrierFlow does
not read, copy, expose, attach, or link this identifier. The SDK also creates a
UUIDv7 session ID and event UUID/timestamp. FarrierFlow never calls `identify`,
`alias`, group APIs, person-property APIs, or RevenueCat linking, and every
event is marked not to process a person profile.

## Automatic SDK property audit

PostHog 3.74.0 attaches the following SDK-owned metadata to custom events. No
FarrierFlow business data appears in this inventory.

| Data | Classification | Review note |
| --- | --- | --- |
| Anonymous UUIDv7 distinct/device ID | Necessary | Enables anonymous funnels and retention; persisted by the SDK |
| Session UUIDv7, event UUID, event timestamp | Necessary | Supports event/session ordering; this is not FarrierFlow's deferred session-start event |
| App name, bundle identifier, version, build | Acceptable | Release segmentation and diagnostics |
| SDK name and version | Acceptable | Provider diagnostics |
| Device manufacturer, hardware model, generic device type/name | App Privacy review | Device metadata; no user-assigned device name is sent on iPhone |
| OS name/version | Acceptable; App Privacy review | Compatibility segmentation |
| Screen width/height | Disable if possible | No separate native switch in 3.74.0; attached as context, not a screen-view event |
| Locale/language and timezone | App Privacy review | Regional metadata; no address or GPS data |
| Wi-Fi/cellular reachability booleans | App Privacy review | Network type only; no carrier name was found in 3.74.0 source |
| TestFlight, sideloaded, simulator, iOS-on-Mac, Catalyst booleans | Acceptable | Distribution/runtime diagnostics |
| Source IP visible to ingestion | App Privacy review; minimize | Every event carries the supported `$geoip_disable = true` processing control so PostHog skips GeoIP enrichment. The request still reaches ingestion from an IP address; confirm/disable GeoIP project-side as defense in depth |
| `$is_identified=false`, `$process_person_profile=false` | Necessary privacy controls | Confirms anonymous, no-person-profile processing |

The SDK queues custom events on disk for normal offline delivery. FarrierFlow
adds no analytics queue, retry store, identifier, or event persistence. The
SDK's bundled privacy manifest declares unlinked, non-tracking Product
Interaction and Other Usage Data for analytics, plus User Defaults, System Boot
Time, and File Timestamp required-reason APIs. PostHog's Swift package also
bundles PHPLCrashReporter; its separate manifest declares unlinked,
non-tracking Crash Data and Other Diagnostic Data for app functionality. That
library is present in the built product, but FarrierFlow's explicit
`errorTrackingConfig.autoCapture = false` prevents the crash-reporter
integration from being installed or collecting those data. FarrierFlow's own
manifest still declares only its direct Disk Space required-reason access; both
package manifests are bundled separately and must be included in the release
privacy review.

## Owner privacy follow-up before release

Do not copy questionnaire answers mechanically. The owner should review the
configured build and then:

1. Update App Store Connect App Privacy for unlinked, non-tracking product
   interaction/other usage analytics and the anonymous persistent identifier,
   based on Apple's current definitions.
2. Review device, app, OS, locale/timezone, network-type, distribution, and
   source-IP handling against every applicable questionnaire category.
3. Confirm the PostHog US project disables GeoIP enrichment if the project
   offers that setting. The provider-level `$geoip_disable = true` control is
   defense in depth, but does not prevent the network request from originating
   at the device's IP address.
4. Verify the archived app contains FarrierFlow's, PostHog's, and the bundled
   PHPLCrashReporter privacy manifests. Confirm App Store Connect does not infer
   crash/diagnostic collection from the bundled manifest when runtime error
   tracking remains disabled; answer from actual collection behavior and
   Apple's current guidance rather than the package declaration alone.
5. Update the public Privacy Policy before this analytics-enabled build ships:
   name PostHog, describe anonymous usage events and SDK metadata, the persistent
   anonymous identifier, US ingestion, offline queue/retention behavior, and
   state explicitly that business records and record contents are excluded.

No App Store Connect or public-site changes are part of this unit.

## Owner PostHog checklist

- Confirm the configured public project token belongs to the intended project.
- Confirm the ingestion host matches the US project region.
- Confirm Session Replay is disabled in project settings as defense in depth.
- Confirm no surveys, experiments, or feature flags are expected for this release.
- Confirm GeoIP enrichment is disabled if the project exposes that control.
- After privacy approvals, verify one non-sensitive custom event in a development
  build without logging the token, distinct ID, or payload.

RevenueCat now owns Standard Apple AdServices attribution behind the existing
subscription-provider boundary. Its initialization, privacy constraints,
owner-side Advanced integration setup, and production verification limits are
documented in [Apple Ads Attribution](apple-ads-attribution.md). Apple Ads data
does not enter this analytics contract or PostHog.

Rating prompts, dashboards, experiments, session replay, and runtime semantics
for first-open/session-start remain separate future units.
