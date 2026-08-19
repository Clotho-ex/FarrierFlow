# FarrierFlow 1.0 Submission Checklist

This is a local release gate checklist. It records current evidence and does
not authorize portal changes, signing, archiving, uploading, TestFlight, or
submission.

## Completed local Unit 6 work

- [x] iOS-only multilayer `FarrierFlow/Resources/AppIcon.icon` created in
  Apple Icon Composer with Default, Dark, and Mono appearances.
- [x] `FarrierFlow/PrivacyInfo.xcprivacy` declares no tracking, no collected
  data, and the Disk Space required-reason API with `E174.1`.
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
  version 1.0 draft submission; each product reported **Ready for Review**.
- [x] On 2026-08-18, complete the source-backed age-rating questionnaire; App
  Store Connect calculated and saved a 4+ rating.
- [x] On 2026-08-18, publish App Privacy as **Data Not Collected** for the final
  binary and enter the verified Privacy Policy URL.

## Candidate and submission gates (Unit 7 only)

- [x] Integrate Revenue Launch Units 1–6 with the latest owner-workflow changes
  on local `main`, including the approved Unit 7 launch-synchronization test
  fixes. No Export Unit 2, backup, account, analytics, or mutation-coordinator
  work is included.
- [x] On 2026-08-15, App Store Connect showed **No Builds** in TestFlight and no
  build attached to version 1.0. Project build number `1` was therefore the
  first available upload candidate at that check.
- [x] On 2026-08-15, complete the serial local release verification gates on
  the pre-integration release branch: iOS 18 and iOS 26 unit/integration suites
  each passed 396 tests; the focused iOS 18 subscription and first-customer
  gate passed 6 tests; the full iOS 26 UI gate passed 22 tests; both
  persistent-reopen gates passed 16 tests; both simulator builds succeeded;
  and the source and built privacy manifests, string catalog, compiled
  Default/Dark/tinted App Icon renditions, and `git diff --check` passed.
- [x] On 2026-08-19, run the complete serial release-candidate verification
  matrix on the integrated local `main` candidate rooted at `463b81a`: the
  iOS 18 and iOS 26 unit/integration suites each passed 412 tests; the focused
  iOS 18 subscription and first-customer gate passed 6 tests; the expanded
  full iOS 26 UI gate passed 30 tests; both persistent-reopen gates passed 16
  tests; and both Simulator builds succeeded. Source and built privacy
  manifests, localization compilation, StoreKit JSON/product contracts,
  version 1.0/build 1/minimum iOS 18 metadata, compiled Default/Dark/tintable
  App Icon renditions, and `git diff --check` passed. The initial focused iOS
  18 attempt exposed ignored Today navigation taps in
  `OwnerSetupUITests`; two independent result bundles retained the correct
  product data on Today, and a bounded condition-based retry fixed the test
  synchronization without changing production behavior. The exact selector
  and complete affected gates then passed.
- [x] On 2026-08-20, capture and visually accept the final six-shot App Store
  product-page set from the integrated release candidate on the iOS 26.5
  iPhone 17 Pro Simulator. All six local assets use deterministic sanitized
  fixtures and are 1206 x 2622 RGB JPEGs with no alpha channel.
- [ ] Upload the accepted six-shot set to App Store Connect. The last live
  portal check still showed 0 of 10 iPhone screenshots because Chrome
  file-chooser access blocked the upload; reconfirm that state before acting.
- [ ] Finish the prepared metadata. On 2026-08-18, the subtitle, promotional
  text, description, keywords, Support URL, Business category, and review notes
  were saved, and **Sign-in required** was cleared for this account-free app.
  Copyright, exact review contact, Content Rights, and final release-behavior
  confirmation remain open.
- [ ] Archive, upload, and process one signed release candidate.
- [ ] Complete TestFlight and physical-iPhone acceptance.
- [ ] Finish the remaining verified metadata, upload the accepted screenshots,
  then submit the already attached first subscriptions with version 1.0 for
  review.
