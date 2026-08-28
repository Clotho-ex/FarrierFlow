# FarrierFlow 1.0 Submission Checklist

This is a local release gate checklist. It records current evidence and does
not authorize portal changes, signing, archiving, uploading, TestFlight, or
submission.

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
  sanitized 1206 x 2622 review screenshot to both products and add both to the
  review draft; each product now reports **Ready for Review**. On 2026-08-28,
  add the required `FarrierFlow Pro` subscription group to the same draft.
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

- [ ] Freeze a new release-candidate source boundary after the RevenueCat and
  structured-payment implementation is reviewed and committed.
- [x] On 2026-08-15, App Store Connect showed **No Builds** in TestFlight and no
  build attached to version 1.0. Project build number `1` is therefore the
  first available upload candidate.
- [x] On 2026-08-15, complete the serial local release verification gates:
  iOS 18 and iOS 26 unit/integration suites each passed 396 tests; the focused
  iOS 18 subscription and first-customer gate passed 6 tests; the full iOS 26
  UI gate passed 22 tests; both persistent-reopen gates passed 16 tests; both
  simulator builds succeeded; and the source and built privacy manifests,
  string catalog, compiled Default/Dark/tinted App Icon renditions, and
  `git diff --check` passed.
- [ ] Capture final App Store screenshots from the shipping candidate, with no
  private customer or account data. The one current sanitized 1206 x 2622
  asset is valid for the 6.3-inch slot, but version 1.0 still has 0 of 10
  iPhone screenshots because Chrome file-chooser access blocked the upload;
  broader planned product-page coverage also remains unfinished.
- [ ] Enter the prepared subtitle, promotional text, description, keywords,
  Support URL, copyright, category, review contact, and review notes. On
  2026-08-18, the subtitle, promotional text, description, keywords, Support
  URL, Business category, and review notes were saved, and **Sign-in required**
  was cleared for this account-free app. Copyright, exact review contact,
  Content Rights, and final release-behavior confirmation remain open.
- [ ] Archive, upload, and process one signed release candidate.
- [ ] Complete TestFlight and physical-iPhone acceptance.
- [ ] Finish the remaining verified metadata and screenshots, upload and select
  the release-candidate build, complete Content Rights and App Review contact
  information, then add version 1.0 to the draft that already contains both
  subscriptions and the `FarrierFlow Pro` group. Submit for review only after
  the excluded sandbox/TestFlight lifecycle acceptance is complete.
