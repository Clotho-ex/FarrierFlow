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

## Unmet public and commercial gates

- [ ] Owner supplies a real monitored public support contact.
- [ ] Separate website project publishes approved Privacy Policy and Support
  pages at owner-controlled HTTPS URLs.
- [ ] Verify both public URLs without authentication and enter them in App
  Store Connect.
- [ ] Inspect Paid Apps Agreement, tax, and banking status read-only; the
  owner completes any required agreements and financial setup.
- [x] Unit 5 created and localized the `FarrierFlow Pro` subscription group
  and monthly/yearly products in App Store Connect. Both United States products
  have the 14-day introductory offer, and the 16-day All Renewals billing grace
  period is enabled in production and sandbox. This checklist relies on the
  recorded Unit 5 evidence in `docs/release/storekit-configuration.md`; Unit 6
  did not re-inspect or mutate App Store Connect. The group and products remain
  Prepare for Submission and still must be attached to version 1.0 for review.
- [ ] Complete the current App Store Connect age-rating questionnaire and
  confirm App Privacy remains Data Not Collected for the final binary.

## Candidate and submission gates (Unit 7 only)

- [ ] Freeze approved source scope and set an approved monotonically increasing
  build number.
- [ ] Run the complete serial iOS 18 and iOS 26 release verification gates.
- [ ] Capture final App Store screenshots from the shipping candidate, with no
  private customer or account data.
- [ ] Archive, upload, and process one signed release candidate.
- [ ] Complete TestFlight and physical-iPhone acceptance.
- [ ] Enter verified metadata and public URLs, attach the first subscriptions,
  and submit version 1.0 for review.
