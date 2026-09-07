# FarrierFlow 1.0 Submission Checklist

This release gate checklist records current evidence. The 2026-09-05 release
certification authorizes signed archiving, validation, build/TestFlight upload,
screenshot upload, and source-backed App Store Connect draft preparation. It
does not authorize **Add for Review** or **Submit for Review**.

## Completed local Unit 6 work

- [x] iOS-only multilayer `FarrierFlow/Resources/AppIcon.icon` created in
  Apple Icon Composer with Default, Dark, and Mono appearances.
- [x] `FarrierFlow/PrivacyInfo.xcprivacy` declares no tracking and retains the
  Disk Space required-reason API with `E174.1`; built-product inspection must
  also include RevenueCat's package privacy manifest.
- [x] Local Privacy Policy, Support, and App Store metadata sources prepared.
- [x] Required-reason API audit and local build/bundle verification recorded in
  the Unit 6 report.

## Public and commercial gates

- [ ] Confirm the published `farrierflow.support@gmail.com` mailbox is actively
  monitored and can send replies from that public address.
- [x] Separate website project publishes the approved Privacy Policy and Support
  pages at `https://farrierflow.vercel.app/privacy/` and
  `https://farrierflow.vercel.app/support/`.
- [x] On 2026-08-15, both public URLs returned HTTP 200 without authentication
  and the Support page displayed `farrierflow.support@gmail.com`.
- [x] On 2026-08-18, enter the verified Privacy Policy and Support URLs in App
  Store Connect.
- [x] On 2026-08-15, inspect Business read-only: the Free Apps Agreement is
  Active, the Paid Apps Agreement is New, and Apple requires the legal entity
  information to be updated before that agreement can be signed. No agreement,
  identity, tax, or banking state was changed.
- [x] On 2026-08-18, verify Business read-only after the owner completed the
  commercial setup: the Paid Apps Agreement is Active, the bank account is
  Active, and both submitted U.S. tax forms are Active. No financial or legal
  details were changed or recorded in this repository.
- [x] On 2026-08-18, verify Apple Developer Account records the newly updated
  Apple Developer Program License Agreement as issued and accepted on that
  date.
- [x] On 2026-09-06, live Business inspection confirmed the stale agreement
  banner is cleared and both Free Apps and Paid Apps agreements are Active.
- [x] On 2026-08-18, configure the app as a free download in the United States,
  matching both subscriptions' one-country launch availability.
- [x] On 2026-08-18, disable Apple-Silicon Mac and Apple Vision Pro
  availability for the approved iPhone-only 1.0 scope.
- [x] Unit 5 created and localized the `FarrierFlow Pro` subscription group
  and monthly/yearly products in App Store Connect. Both United States products
  have the 14-day introductory offer, and the 16-day All Renewals billing grace
  period is enabled in production and sandbox. On 2026-08-18, upload the
  sanitized 1206 x 2622 review screenshot to both products; each product
  reported **Ready for Review**. The live 2026-09-06 Draft Submission contains
  the FarrierFlow Pro group plus FarrierFlow Monthly and FarrierFlow Yearly.
- [x] On 2026-08-18, complete the source-backed age-rating questionnaire; App
  Store Connect calculated and saved a 4+ rating.
- [x] On 2026-08-28, replace the prior **Data Not Collected** answer with Purchase History used
  for App Functionality and Analytics, not linked to identity and not used for
  tracking, then republish App Privacy.
- [x] On 2026-08-28, deploy the RevenueCat disclosure update to the public
  Privacy Policy and verify the home, Privacy, and Support routes return HTTP
  200.
- [x] In RevenueCat, create the Apple app, import both products, attach them to
  entitlement `pro`, configure the current monthly/yearly Offering, add the App
  Store In-App Purchase key, supply the public Apple SDK key, and set restore
  behavior to `Transfer to new App User ID`.
- [x] Configure RevenueCat's Apple App Store Server Notification URL in App
  Store Connect and obtain RevenueCat's successful configuration validation.
- [ ] Confirm server-notification receipt delivery during the real Apple
  sandbox/TestFlight lifecycle acceptance run.

## Candidate and submission gates (Unit 7 only)

- [x] On 2026-08-29, revalidated the final release-onboarding source: adaptive launch screen,
  fresh and interrupted first-run flow, existing-workspace compatibility,
  Offering-authoritative trial copy, Pro skip/purchase/restore handoff,
  read-only recovery, contextual hints, relaunch, accessibility XXXL,
  localization, iOS 18/iOS 26 builds, and final diff audit.
- [x] Freeze the original reviewed application release candidate at local
  commit `cee7a12381a22b6bf95632368508d2df3ba9cd61`; no push was performed.
  This RC and its build 1 were superseded for submission by the owner-authorized
  2026-09-06 UI corrections below.
- [x] On 2026-09-05, App Store Connect showed **No Builds** in TestFlight and no
  build attached to version 1.0. Project build number `1` remains unused and is
  the first available upload candidate.
- [x] On 2026-08-15, complete the serial local release verification gates:
  iOS 18 and iOS 26 unit/integration suites each passed 396 tests; the focused
  iOS 18 subscription and first-customer gate passed 6 tests; the full iOS 26
  UI gate passed 22 tests; both persistent-reopen gates passed 16 tests; both
  simulator builds succeeded; and the source and built privacy manifests,
  string catalog, compiled Default/Dark/tinted App Icon renditions, and
  `git diff --check` passed.
- [x] On 2026-08-29, revalidate the completed RevenueCat and structured-payment
  implementation from source boundary `7d7f44b`: iOS 18 and iOS 26 each passed
  436 discovered unit/integration tests representing 507 parameterized test
  executions; the focused iOS 18 subscription/payment/relaunch gate passed 3
  UI tests; the full iOS 26 UI target passed 36 tests; and the explicit
  schema, persistent-reopen, invoice-generation, and invoice-payment gate
  passed 34 tests. Both simulator builds succeeded after verifying that the
  processed app Info.plist contains the configured RevenueCat public Apple SDK
  key. RevenueCat 5.87.1 was confirmed as the current stable, non-prerelease
  release and remains resolved exactly in `Package.resolved`. Localization,
  source and built privacy manifests, StoreKit product contracts, credential
  and mutation-boundary scans, and `git diff --check` passed.
- [x] On 2026-09-05, certify current head serially: iOS 18 and iOS 26 each
  passed 475 declared unit/integration tests in 72 suites, representing 558
  parameterized executions; the focused iOS 18 UI gate passed 43 tests; the
  full iOS 26 UI target passed 60 tests; and both fresh Release simulator
  builds succeeded. Localization, plist and StoreKit JSON validation,
  credential-name scan, both built app and RevenueCat privacy manifests,
  absence of `.storekit` and test/debug artifacts from both Release bundles,
  screenshot specifications, and `git diff --check` passed.
- [x] Locally validate the seven corrected product-page exports in
  `/Users/prometheus/Desktop/Updated-Screenshots-Figma-Export`: every file is a
  1320 x 2868 JPEG with no alpha channel. Seven files are intentional because
  two adjacent images form one continuous visual. The historical repository
  screenshot sets are superseded.
- [x] On 2026-09-06, live App Store Connect inspection confirmed all seven
  corrected exports in the 6.9-inch slot in saved order. The 6.5-inch slot
  inherits all seven from 6.9-inch. The draft has zero App Previews by owner
  choice; a preview is optional and is not a blocker.
- [ ] Enter the prepared subtitle, promotional text, description, keywords,
  Support URL, copyright, category, review contact, and review notes. On
  2026-08-18, the subtitle, promotional text, description, keywords, Support
  URL, Business category, and review notes were saved, and **Sign-in required**
  was cleared for this account-free app. Live inspection on 2026-09-06
  confirmed the source-backed metadata remains saved, the three subscription
  items are in the Draft Submission, and no build is attached. Copyright plus
  review-contact first name, last name, phone, and email remain blank; Content
  Rights and owner-selected release behavior also remain open.
- [x] Create `/tmp/FarrierFlow-1.0-RC.xcarchive` from the immutable RC and
  verify its signature, version/build, iPhone/iOS settings, icons/assets,
  privacy manifests, RevenueCat static linkage/resource bundle, and absence of
  test/debug/`.storekit` artifacts.
- [x] On 2026-09-05, the owner authenticated Xcode and reported successful
  Organizer validation of `/tmp/FarrierFlow-1.0-RC.xcarchive`; the exact frozen
  archive upload then succeeded and App Store Connect displayed TestFlight
  version 1.0 build 1. The owner reported saving its source-backed
  export-compliance answer on 2026-09-06. Build 1 is now superseded for
  submission by the corrected application source.
- [x] Implement and focus-test the approved post-RC UI corrections: top invoice
  toolbar actions, floating full-width Next Appointment Continue, inline-large
  Today/Schedule/Clients titles with accessibility fallback and existing 8/16
  point spacing tokens, and one visible Hoof Photos label in each Visit horse
  section. Six focused UI tests passed across iOS 18 and iOS 26; the iOS 18
  Release simulator build, localization compilation, and `git diff --check`
  passed.
- [x] Revalidate the complete Next Appointment boundary after updating only its
  UI harness for current native controls: the iOS 26.5 UI suite passed 2/2,
  including persistence/reopen, and the iOS 18.0 model suite passed all 9
  declared tests (14 parameterized executions) with no failures or skips,
  including manual date/time override behavior. The native virtual Toggle
  activation issue on the iOS 18 simulator is an XCTest/simulator interaction
  limitation, not a reproduced product failure.
- [x] Set the application target to build 2, then pass a fresh iOS 26.5 Release
  simulator build and verify the built app reports 1.0 (2), includes both
  privacy manifests, and excludes `.storekit`. Localization, plist/StoreKit
  validation, and `git diff --check` also passed.
- [x] On 2026-09-06, live TestFlight showed only build 1, Ready to Submit, with
  no invites or installs. Build 2 is the smallest unused build number.
- [x] Audit and freeze the corrected source as immutable build 2 RC
  `b1d4a8ea55fb14ce56b81a2c0fba73da5b5a8611` in a local commit without a
  push. The explicit allowlist excluded all pre-existing untracked artifacts.
- [x] Create `/tmp/FarrierFlow-1.0-build2-RC.xcarchive` from that exact SHA and
  pass version/build, signature, entitlement, privacy-manifest, RevenueCat,
  icon, artifact-exclusion, binary-hash, and source-integrity inspection.
- [x] Validate/upload the unchanged build 2 archive after restoring Xcode's
  Apple Account session. Xcode reported `Upload succeeded` and
  `** EXPORT SUCCEEDED **`; live TestFlight showed build 2 Ready to Submit
  after its source-backed export-compliance answer was saved.
- [x] Attach only build 2 to version 1.0 and verify the saved draft displays
  build 2 / version 1.0. Build 1 remains superseded for submission.
- [x] Create the internal TestFlight group `FarrierFlow 1.0 RC` with automatic
  future-build distribution disabled, then add only build 1.0 (2). Live
  App Store Connect showed the group with one build in `Ready to Test` state
  on 2026-09-07. The Account Holder was then added as the sole internal tester;
  the live tester status was `Invited`, with no install yet inferred.
- [x] Owner reported installing TestFlight build 1.0 (2) on an iPhone 14 Pro
  running iOS 26.6.1 on 2026-09-07. At the immediate portal recheck the tester
  still showed `Invited` with no session, so runtime acceptance is not inferred.
- [x] Because an earlier FarrierFlow build had existed on the device, the owner
  deleted it and reinstalled build 1.0 (2) from TestFlight before opening it.
  This establishes the clean-install prerequisite.
- [x] The owner completed the clean first-run path through briefing and business
  identity to `FarrierFlow Pro`. Supplied device screenshots show both monthly
  and yearly products, yearly selected by default, a two-week free trial,
  `$14.99/month`, and `$119.99/year`; there was no plans-unavailable state.
  Apple's confirmation sheet showed `₺5,999.99/year` for the Turkish storefront.
  [RevenueCat documents](https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store)
  USD Offerings metadata beside correctly localized Apple purchase sheets as a
  known TestFlight/sandbox quirk; the shipping client uses RevenueCat's
  `localizedPriceString` rather than a hardcoded production price.
- [x] The owner completed the yearly TestFlight sandbox purchase on the same
  physical device. The app showed `Completing Purchase...`, Apple's `You're all
  set` confirmation appeared after about two seconds, and FarrierFlow routed to
  Today about two seconds later. RevenueCat sandbox data independently records
  the matching Turkish `INITIAL_PURCHASE` for `FarrierFlow Yearly`, entitlement
  ID `pro`, and an Active `FarrierFlow Pro` entitlement. This passes yearly
  purchase and entitlement activation only; trial, monthly purchase, Restore,
  entitlement loss/read-only, reactivation, and App Store Server Notification
  receipt remain separate gates.
- [x] On the active physical-device entitlement, the owner created the
  fictional Willow Creek Stables appointment with its fictional address and
  both Atlas and Beacon. Device evidence shows the appointment as the scheduled
  Next Stop on Today; visit, photo, invoice, payment, follow-up, and relaunch
  acceptance remain in progress.
- [x] The owner used the physical iPhone camera from Atlas → Hoof Photos, saved
  one image, saved Visit progress, and reopened the Visit. The supplied device
  screenshot shows Atlas retaining a Hoof Photos count of `1`; physical capture
  and photograph persistence therefore pass.
- [x] The owner completed the physical Visit with Atlas Serviced and Beacon Not
  Serviced. The resulting Next Appointment assistant preserved Willow Creek
  Stables, proposed Atlas at its six-week interval, selected Atlas, and excluded
  Beacon from the suggestion.
- [x] The owner continued from the assistant and saved the proposed follow-up.
  Physical-device evidence shows the September 7 Willow Creek appointment as
  Completed and the October 19 appointment persisted with Atlas only; next-
  appointment creation therefore passes.
- [x] The owner generated physical-device Invoice 0001 from the completed
  September 7 Visit. Device evidence shows Unpaid status, Jordan Ellis, Willow
  Creek Stables, Atlas → Full Set, a `$220.00` amount due, the 14-day due date,
  and the expected paid/share/more toolbar actions.
- [x] The owner shared Invoice 0001 to Files, opened the generated one-page PDF,
  and returned to FarrierFlow. The PDF preserved the invoice number, status,
  business/client/location/date snapshots, Atlas → Full Set line item, totals,
  and page footer without clipping; the app remained responsive on return.
- [x] The owner recorded Invoice 0001 as paid by Bank Transfer. Physical-device
  evidence shows Paid status, paid amount `$220.00`, payment date September 7,
  2026, method Bank Transfer, reference `BANK-TEST-0001`, and removal of the
  Mark as Paid toolbar action.
- [ ] Complete TestFlight and physical-iPhone acceptance.
- [ ] Finish the remaining owner-supplied metadata, upload and select
  the replacement release-candidate build, and complete Content Rights,
  copyright, App Review contact information, and the owner-selected release
  behavior. The screenshots, 4+ rating, U.S.-only availability, Mac/Vision
  exclusions, Sign-in Required false state, both subscriptions, and the
  `FarrierFlow Pro` group are already verified. Stop with the version in draft;
  submission is a separately authorized action after sandbox/TestFlight
  lifecycle acceptance.
