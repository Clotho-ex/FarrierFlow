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
- [ ] Reconfirm App Store Connect has cleared its stale agreement-review banner
  before upload or submission. The immediate post-acceptance refresh still
  displayed the banner even though Apple Developer Account recorded the new
  agreement as accepted.
- [x] On 2026-08-18, configure the app as a free download in the United States,
  matching both subscriptions' one-country launch availability.
- [x] On 2026-08-18, disable Apple-Silicon Mac and Apple Vision Pro
  availability for the approved iPhone-only 1.0 scope.
- [x] Unit 5 created and localized the `FarrierFlow Pro` subscription group
  and monthly/yearly products in App Store Connect. Both United States products
  have the 14-day introductory offer, and the 16-day All Renewals billing grace
  period is enabled in production and sandbox. On 2026-08-18, upload the
  sanitized 1206 x 2622 review screenshot to both products; each product
  reported **Ready for Review**. Historical notes said both products and the
  group were added to the version draft. A live read-only check on 2026-09-05
  showed no in-app purchases or subscriptions attached to version 1.0, so
  attachment remains an open portal gate.
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
- [ ] Freeze a new release-candidate source boundary after the RevenueCat and
  structured-payment implementation is reviewed and committed.
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
- [x] Capture and locally validate six final 1320 x 2868 6.9-inch App Store
  screenshots from deterministic fictional fixtures on the iPhone 17 Pro Max
  iOS 26.5 simulator, with no private customer, account, or testing-label data.
  The existing 1206 x 2622 6.3-inch repository set is superseded.
- [ ] Replace the seven stale custom 6.9-inch screenshots observed in App Store
  Connect on 2026-09-05 with the exact six final release-candidate assets. The
  6.5-inch slot currently inherits the 6.9-inch set; add a separate 6.3-inch set
  only if the live portal requires one.
- [ ] Enter the prepared subtitle, promotional text, description, keywords,
  Support URL, copyright, category, review contact, and review notes. On
  2026-08-18, the subtitle, promotional text, description, keywords, Support
  URL, Business category, and review notes were saved, and **Sign-in required**
  was cleared for this account-free app. A live check on 2026-09-05 confirmed
  no build or subscriptions attached and found copyright plus the review
  contact name, phone, and email blank. Content Rights and final
  release-behavior confirmation also remain open.
- [ ] Archive, upload, and process one signed release candidate.
- [ ] Complete TestFlight and physical-iPhone acceptance.
- [ ] Finish the remaining verified metadata and screenshots, upload and select
  the release-candidate build, complete Content Rights and App Review contact
  information, and attach both subscriptions plus the `FarrierFlow Pro` group
  to version 1.0. Stop with the version in draft; submission is a separately
  authorized action after sandbox/TestFlight lifecycle acceptance.
