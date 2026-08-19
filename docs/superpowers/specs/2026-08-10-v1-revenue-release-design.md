# FarrierFlow 1.0 — Revenue Release Design

**Status:** Commercial decisions approved; implementation contract awaiting
review

**Date:** 2026-08-10

## Purpose

FarrierFlow 1.0 ships the completed independent-farrier workflow and begins
earning revenue without waiting for Export, backup, cloud services, payment
processing, or additional feature breadth. The first release prioritizes the
records and actions a working farrier needs today:

appointment → horse history → completed work → hoof photographs → invoice →
payment status → next appointment

The App Store download is free. Creating or changing business records requires
one auto-renewable subscription. A farrier whose subscription ends keeps
permanent read-only access to all existing local records and documents.

## Chosen Release Approach

Release from the narrow `origin/main` product baseline, not from the unfinished
Slice 8 snapshot branch. Preserve completed Slice 8 work on its feature branch
and pause the remaining Export units until after revenue launch. Port only the
confirmed stale-Appointment integrity fix that is independently required by the
shipping workflow.

Add one StoreKit-owned Subscription feature. It determines whether ordinary
production mutation controls are available, presents Apple's native
subscription store, and never owns or rewrites business data. StoreKit signed
transactions remain the entitlement source of truth; SwiftData remains the
business-record source of truth.

### Alternatives Considered

1. **Subscription launch before finishing Export — chosen.** It monetizes the
   already-complete core workflow and keeps the remaining release surface
   small.
2. **Finish Export before charging — rejected for 1.0.** Six substantial Export
   units remain and do not improve the first customer's daily service cycle.
3. **Paid-up-front download — rejected.** It is faster technically, but the
   approved product model requires a free download, trial, and recurring
   monthly or yearly revenue.
4. **Writable free tier — rejected.** It adds limits, counters, upgrade rules,
   and more product states. Permanent read-only access is simpler and ensures
   the owner is never locked away from existing business records.

## Commercial Contract

### Products

Use one auto-renewable subscription group named **FarrierFlow Pro** with two
products:

| Product | Product identifier | US launch price | Introductory offer |
| --- | --- | --- | --- |
| Monthly | `com.farrierflow.yusufcan.FarrierFlow.pro.monthly` | `$14.99/month` | 14 days free |
| Yearly | `com.farrierflow.yusufcan.FarrierFlow.pro.yearly` | `$119.99/year` | 14 days free |

The yearly plan is the recommended option and is equivalent to $10 per month.
Apple supplies localized prices and manages taxes, renewal, cancellation,
refunds, and storefront currency. FarrierFlow must never hard-code a localized
display price outside StoreKit test fixtures.

There is no weekly, lifetime, consumable, team, or feature-tier product in 1.0.
Family Sharing, offer codes, promotional offers, win-back offers, and server
receipt validation are excluded from 1.0. A customer receives at most one
introductory offer across the subscription group under Apple's eligibility
rules.

### Access States

FarrierFlow has three runtime access states:

- **Loading:** Entitlement resolution has not completed. Business records are
  not mutated and no subscription conclusion is shown yet.
- **Full access:** A verified current entitlement exists for either approved
  product. This includes an active paid period, the 14-day introductory trial,
  a canceled subscription before its paid-through date, and Apple's billing
  grace period.
- **Read only:** No verified current entitlement exists. This includes a new
  user who has not subscribed, expiration after grace, billing retry outside
  grace, revocation, refund, or an unverified transaction.

Configure a **16-day billing grace period** for **All Renewals** in App Store
Connect for production and sandbox testing. During grace, the signed transaction
remains a current entitlement and FarrierFlow continues full access.
Billing-retry state outside grace is read only. A later successful renewal
restores full access without changing business data.

StoreKit's verified `Transaction.currentEntitlements` sequence is the sole
allow/deny boundary. It includes subscribed and grace-period transactions and
excludes expired, billing-retry, and revoked transactions. FarrierFlow listens
for verified `Transaction.updates` and refreshes access while running. It does
not invent an additional expiry cache, persist a Boolean entitlement, or trust
an unverified transaction.

### Full Access

Full access preserves every implemented 1.0 workflow, including:

- Create, edit, and permitted deletion of Clients, Horses, Service Locations,
  Appointments, Services, and owner defaults.
- Start, save, complete, correct, and permitted discard of Visits.
- Add and delete hoof photographs.
- Generate and permitted deletion of Invoices and mark Invoices Paid.
- Use next-Appointment assistance and save the resulting ordinary Appointment.
- View and share invoice PDFs.

### Read-Only Access

Read-only access preserves:

- Today, Schedule, Client, Horse, Service Location, Service, Visit, Photograph,
  and Invoice navigation.
- Complete existing history and immutable snapshots.
- Viewing available canonical photographs.
- Generating, opening, printing, and sharing a PDF from an existing persisted
  Invoice snapshot. This creates only the ordinary temporary PDF and no Invoice
  or other business record.
- The Subscription screen, Restore Purchases, and Manage Subscription.

Read-only access removes or disables every ordinary production action that can
change business truth:

- No create, edit, delete, archive, reactivate, relocation, or owner-default
  save.
- No Visit start, progress save, completion, correction, WorkItem change, or
  discard.
- No photograph add or delete.
- No Invoice generation, deletion, or payment-status change.
- No continuation from next-Appointment assistance into a saveable draft.

The app does not delete, hide, export, upload, repair, or alter source records
when access changes. Photograph reconciliation and protected file cleanup may
continue because they preserve the integrity of already-owned local data and
are not customer business-record creation.

If access becomes read only while an editor is already open, draft editing may
remain in memory, but Save and every destructive or committing action become
unavailable immediately. Visit background saving also stops. Cancel, Done,
navigation, viewing, and invoice PDF sharing remain available.

## First-Run and Returning Flows

### New Download Without an Entitlement

1. Launch and resolve StoreKit entitlement before exposing mutation.
2. When no Business Profile and no entitlement exist, show a native
   subscription welcome screen rather than owner setup or fabricated sample
   data.
3. Explain the connected field workflow, local-only data ownership, prices,
   recurring terms, and 14-day trial without urgency or misleading scarcity.
4. Present the monthly and yearly products through `SubscriptionStoreView`.
5. After a verified purchase update, proceed to the existing single-field owner
   setup and then Today.

### Active or Trial Subscriber

An active subscriber enters the existing app. A subscriber without a Business
Profile completes the existing owner-identity step first. StoreKit does not add
an account, password, or second onboarding flow.

### Lapsed Subscriber With Existing Data

The existing Business Profile and records open normally in read-only mode.
Today shows one calm read-only notice with a route to Subscription. Mutation
controls are absent or disabled, while all viewing and invoice PDF access
remain intact. Resubscribing restores normal controls after the verified
entitlement refresh.

### Restore and Manage

The Subscription screen always provides Apple's native Restore Purchases
button. When a current or prior subscription is present, it also provides the
native Manage Subscription sheet. Restore errors remain on the store surface
and never affect local business records.

## Interface Design

- Introduce `Features/Subscription/` only; do not create generalized Settings,
  Accounts, Billing, or Paywall frameworks.
- Add **Subscription** to Clients > More alongside concrete owner tools.
- Use `SubscriptionStoreView` so Apple supplies localized names, durations,
  prices, purchase confirmation, recurring terms, and policy actions.
- Use a flat native marketing header: FarrierFlow name, one concise value
  statement, and the existing workflow. Do not use a card grid, countdown,
  fake discount, testimonials, or fabricated customer evidence.
- Use the existing Survey Ink accent sparingly for the primary subscription
  action and read-only notice.
- Read-only mode adds one compact Today section, not a blocking overlay or a
  warning repeated on every record screen.
- Mutation actions disappear when their absence remains understandable. An
  already-open editor keeps Cancel or Done and shows concise read-only
  explanation while its committing controls are disabled.
- Invoice PDF generation and sharing from an existing Invoice remains visually
  unchanged in read-only mode.
- Support VoiceOver, accessibility Dynamic Type, Light/Dark Mode, Increased
  Contrast, and Reduce Motion using native StoreKit and SwiftUI behavior.

## Architecture

### Feature Ownership

`Features/Subscription/` owns:

- Stable product identifiers.
- The access-state value.
- StoreKit current-entitlement and update observation.
- A main-actor observable access model.
- The native subscription store and read-only notice.
- Restore and Manage Subscription presentation.

`FarrierFlowApp` creates one production entitlement source and one
`SubscriptionAccessModel`, then injects the model through SwiftUI's environment.
Previews and UI tests inject deterministic access instead of depending on the
App Store.

`RootView` coordinates only the top-level combination of entitlement readiness
and existing owner-setup readiness. It does not buy products, parse receipts,
or mutate business records.

Existing feature views read the injected access model only to expose their own
mutation controls. Existing feature models and SwiftData types do not depend on
StoreKit. This is deliberate: entitlement affects whether the user may invoke a
mutation, not the validity or ownership of business data.

### Concurrency and Offline Behavior

The StoreKit entitlement source is `Sendable` and reads only verified StoreKit
transactions. `SubscriptionAccessModel` is `@MainActor @Observable`; it updates
interface state and owns one cancellable listener task.

StoreKit's locally available signed transaction history permits current
entitlement resolution without adding FarrierFlow networking or an account.
If product merchandising cannot load, existing verified entitlement still
controls access. If entitlement verification cannot establish a valid current
transaction, FarrierFlow fails closed to read only without touching data.

### Persistence

Subscription state is not part of SwiftData and causes no schema or migration
change. No entitlement, trial date, grace date, App Store customer identifier,
receipt, or transaction is persisted in BusinessProfile or another model.

Every read-only screen continues reading the same shared `ModelContainer` and
canonical photograph files. Access transitions never call `save`, `rollback`,
`delete`, migration, reconciliation repair, or file removal on behalf of the
subscription feature.

## Release Baseline and Scope

Release work starts from `origin/main` after Slice 8 Unit 1. The unfinished
Slice 8 Unit 2 branch remains preserved and unmerged for post-launch work.

Port the stale-Appointment fix independently: validate all selected Horses
before inserting a new Appointment. A stale selection must leave zero inserted
Appointments and must not poison the same `ModelContext` for a corrected retry.

Do not port Slice 8's export-only mutation coordinator or other broad
cross-feature changes into 1.0. They solve unfinished export consistency rather
than a normal shipping workflow requirement.

## App Store Readiness Contract

The following are release blockers, not optional polish:

- Use Apple's current Icon Composer workflow: one iOS-only multilayer
  `FarrierFlow/Resources/AppIcon.icon` with Default, Dark, and Mono
  appearances. Xcode generates the required legacy deployment outputs; do not
  maintain the obsolete three-PNG `AppIcon.appiconset` workflow. The Icon
  Composer document uses vector input layers and no baked transparency.
- Add `PrivacyInfo.xcprivacy` declaring the Disk Space required-reason API used
  to check space before writing photographs, with reason `E174.1`.
- Publish working HTTPS Privacy Policy and Support pages from the separate
  website project, then enter their exact owner-controlled URLs in App Store
  Connect. This repository prepares truthful source content only; it must not
  invent a domain or support contact.
- Use Apple's Standard Licensed Application End User License Agreement for 1.0
  and include its public URL in App Store metadata and the subscription policy
  presentation; add no custom legal terms without separate review.
- Complete App Privacy as **Data Not Collected** only if the final binary and
  public policy still truthfully keep business data on device and add no
  analytics, advertising, account, or external transmission.
- Create the subscription group, products, localizations, prices,
  introductory offers, and grace-period configuration in App Store Connect.
- Complete the Paid Apps Agreement, banking, and tax setup before submission.
- Prepare truthful App Store metadata and screenshots from the shipping app;
  do not fabricate testimonials, customers, or feature claims.
- Submit the first auto-renewable subscriptions with version 1.0 as required by
  App Store Connect.

The icon direction follows the existing Field Book system: a flat,
high-contrast Survey Ink ground with one simple forward workline mark. It must
remain legible at small sizes and avoid horseshoes, western decoration,
gradients, text, screenshots, photographs, and transparent edges. Asset
selection receives visual review before it enters the release candidate.

## Verification and Acceptance

Verification is proportionate to launch risk and centers on business-record
integrity, StoreKit access, and the real owner flow.

### Automated Verification

- Entitlement projection grants full access only for verified monthly or
  yearly current entitlements and treats missing, unverified, expired,
  billing-retry, and revoked results as read only.
- StoreKit updates transition full → read only and read only → full without
  changing SwiftData or photograph files.
- New no-entitlement/no-profile launch shows Subscription; verified access then
  reaches owner setup.
- Existing data opens read-only and every ordinary mutation entry point is
  unavailable while navigation and PDF generation/sharing from existing
  Invoices remain available.
- Entitlement loss while Visit or another editor is open prevents Save,
  completion, deletion, and background persistence.
- Stale Horse selection creates no Appointment and a corrected retry succeeds.
- Existing core unit, persistence-reopening, and UI flows continue with a
  deterministic full-access test entitlement.
- Privacy manifest, string catalog, asset catalog, version/build settings, and
  project builds validate.

### StoreKit and Manual Acceptance

1. Fresh install with no StoreKit entitlement shows the subscription welcome
   surface and both localized plans.
2. Start the monthly 14-day trial and complete owner setup plus the first
   Client → Horse → Appointment flow.
3. Relaunch offline and verify the signed current entitlement retains full
   access and local data remains usable.
4. Complete Visit work with photographs, generate an Invoice, share its PDF,
   mark it Paid, and schedule the next Appointment.
5. Use StoreKit testing to enter billing grace and verify full access.
6. Enter billing retry outside grace or expiration and verify immediate
   read-only behavior with unchanged records and files.
7. Generate and share a PDF from the existing Invoice in read-only mode.
8. Restore or renew and verify full access returns without relaunch or data
   migration.
9. Verify Manage Subscription opens Apple's native sheet.
10. Complete accessibility and appearance checks on the Subscription welcome,
    store, Today read-only notice, and one already-open editor.
11. Install the TestFlight release candidate on a physical iPhone, repeat the
    core paid flow, and verify camera capture, offline operation, purchase,
    restore, and relaunch.

## Explicit Exclusions for 1.0

- Remaining Slice 8 Export implementation, import, or restore.
- App-managed backup, synchronization, CloudKit, user accounts, or a server.
- Payment collection, card processing, reminders, notifications, analytics,
  advertising, attribution, or customer messaging.
- Free writable limits, metered records, plan tiers, teams, seats, web access,
  or family data sharing.
- Weekly, lifetime, one-time, consumable, promotional, offer-code, or win-back
  products.
- Receipt persistence, custom cryptography, server validation, or third-party
  billing dependencies.
- New SwiftData models, fields, schema versions, or migrations.
- Feature polish or defensive hardening that does not block the core workflow,
  data integrity, StoreKit correctness, privacy disclosure, or App Store
  submission.

## Post-Launch Order

1. Fix only crashes, data loss, materially false invoices/exports, broken core
   workflows, subscription access defects, and App Review blockers found in
   real use.
2. Resume Slice 8 Export from its preserved branch when launch is stable.
3. Evaluate backup only after Export and only with a separately approved
   privacy, ownership, recovery, and migration design.
4. Use customer demand and revenue evidence—not speculative completeness—to
   prioritize every additional feature.

## References

- [Apple auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [Apple introductory offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions)
- [Apple billing grace period](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions)
- [StoreKit current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [SubscriptionStoreView](https://developer.apple.com/documentation/storekit/subscriptionstoreview)
- [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
