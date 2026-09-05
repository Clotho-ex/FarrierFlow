# FarrierFlow 1.0 Ship Readiness

**Certification date:** 2026-09-05  
**Immutable application RC:** `cee7a12381a22b6bf95632368508d2df3ba9cd61`  
**Baseline before certification:** `827a4f6d336793011cf9a13dcb08a20dd2b048a4`  
**Uncertified release delta reviewed:** `7d7f44b..827a4f6` (100 files)  
**Version:** 1.0 (build 1)  
**Bundle identifier:** `com.farrierflow.yusufcan.FarrierFlow`  
**Deployment / device family:** iOS 18.0+, iPhone only  
**RevenueCat:** Purchases iOS 5.87.1 at revision
`b65cae4f227be800c57cb9700dbd94f2aa5409b2`

## Verdict summary

The frozen source is a locally certified release candidate. All current-head
unit, integration, UI, Release-build, localization, privacy, screenshot, and
archive-structure gates pass. App Store distribution validation/upload,
processed-build attachment, portal screenshot replacement, TestFlight and
physical-device purchase lifecycle, and support-mailbox operation are not yet
verified. Those external gates keep the overall verdict at NO-GO.

## Toolchain and destinations

- Xcode 26.6 (build 17F113); Swift 6.3.3.
- iOS 18.0: iPhone 16 Pro
  `02DB4E38-DF46-4F30-A8C8-C4D4DF46FDA4`.
- iOS 26.5: iPhone 17 Pro
  `A9501C1D-4747-4310-8F2B-F0587E0E30C6`.
- Screenshot device: iPhone 17 Pro Max iOS 26.5
  `E8A9A417-655D-4531-B872-B351D3EC9DF2`.
- Physical iPhone: `00008120-0016043C0138C01E`, iOS 26.6; offline during
  certification.

## Current-head automated certification

All Xcode operations ran serially with parallel testing disabled and one
maximum test worker. Result bundles and logs are under
`/tmp/farrierflow-cert.rO0al7/`.

| Gate | Discovered / declared | Executed | Passed | Failed | Skipped | Status |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Unit/integration, iOS 18.0 | 475 in 72 suites | 558 parameterized executions | 475 | 0 | 0 | PASS |
| Unit/integration, iOS 26.5 | 475 in 72 suites | 558 parameterized executions | 475 | 0 | 0 | PASS |
| Full UI, iOS 26.5 | 60 | 60 | 60 | 0 | 0 | PASS |
| Focused UI, iOS 18.0 | 43 | 43 | 43 | 0 | 0 | PASS |
| Screenshot capture, iPhone 17 Pro Max | 6 | 6 | 6 | 0 | 0 | PASS |

The focused iOS 18 UI result comprises Connected Records 1, Editor
Accessibility 1, Invoice Flow 3, Next Appointment 1, Owner Setup 17,
Subscription Flow 10, Subscription Read Only 2, and Visit Completion 8. The
full iOS 26 result additionally covers Badge Alignment 7, Blocked Mutation 1,
Formatter Display 1, Root Navigation 1, Today Run Sheet 5, and Visit History
Accessibility 2.

### Required workflow coverage

- Persistence and reopen: PASS — Persistent Store Reopening 16, App Store
  Showcase Fixture 1, Model Container Configurations 4, SwiftData Relationship
  Insertion 4, Schema Contracts 8, Domain Graph Validation 30, and Record
  Deletion Rules 16.
- Scheduling and next appointment: PASS — Appointment Editor 25, Next
  Appointment Assistant 9, Next Appointment Suggestion Rules 11, Schedule
  Model 1, plus the iOS 18/iOS 26 UI flows.
- Visits and work items: PASS — Visit Detail 9, Visit Editor 28, Visit Draft
  Rules 24, Visit Start 6, WorkItem Domain Validation 8, WorkItem Draft Rules
  2, Visit Completion UI 8, and Visit History UI 2.
- Invoice, PDF, and payment: PASS — Invoice PDF Renderer 8, Content Builder 3,
  Share Model 5, Temporary Files 1, Invoice Payment Use Case 6, Payment Mutation
  Boundary 2, and Invoice Flow UI 3. The inspected one-page invoice 0148 and
  19-page long-invoice artifacts contained complete dates, currency, line
  items, totals, pagination, and final notes; PDF share behavior passed UI
  automation.
- Photographs: PASS — Photograph Collection 6, Storage Serialization 6, File
  Store 6, Library 14, Normalizer 5, Reconciliation 5, and Thumbnail View 1;
  UI coverage includes capture/import persistence, full-image behavior,
  deletion rules, and missing-file handling using fictional data.
- Onboarding: PASS — Onboarding Experience 18, Briefing Reveal 2, Business Name
  Rules 4, Owner Setup Readiness 3, and Owner Setup UI 17.
- Subscriptions and read-only: PASS — Subscription Access 14, Products 9, Root
  State 2, Subscription UI 10, Read-Only UI 2, and blocked-mutation UI 1. The
  local StoreKit contract contains only monthly USD 14.99 and yearly USD
  119.99 products, each with a two-week trial; application presentation remains
  yearly first.
- Accessibility and visual tokens: PASS — FarrierFlow Color Tokens 6;
  Editor Accessibility, Badge Alignment, formatter display, compact/XXXL
  subscription, keyboard focus, Light/Dark, Reduce Motion, and semantic-status
  UI paths passed their current suites. The final current-head UI log did not
  reproduce the prior invalid-frame warning.

## Static, configuration, and bundle evidence

- Localization catalog compiled with `xcstringstool --dry-run`: PASS.
- `Info.plist` and app privacy manifest plist lint: PASS.
- StoreKit JSON parse and product/trial contract: PASS.
- `git diff --check` before and after staging: PASS.
- Redacted credential scan: PASS. No private key, certificate, App Store API
  credential, signing material, or server secret was found in tracked source.
  `RevenueCatPublicSDKKey` is publishable client configuration, not a private
  credential.
- App privacy manifest: PASS — no tracking, no collected data, Disk Space
  required-reason API `E174.1`.
- RevenueCat compiled privacy manifest: PASS — Purchase History, not linked,
  not tracking, App Functionality; the published App Privacy disclosure also
  conservatively declares App Functionality and Analytics for RevenueCat
  purchase history.
- Advertising/tracking SDK audit: PASS — no app tracking integration or
  advertising SDK is configured. RevenueCat is statically linked and its
  resource privacy bundle is present.
- Public Privacy and Support pages: PASS — both returned HTTP 200 on
  2026-09-05; the Privacy page contains the RevenueCat/Purchase History and
  local-first disclosures, and Support publishes
  `farrierflow.support@gmail.com`.
- Fresh Release simulator builds on iOS 18.0 and iOS 26.5: PASS. Each compiled
  app contains the app and RevenueCat privacy manifests and contains no
  `.storekit`, `.xctest`, preview dylib, or debug dylib.
- Release warnings: PASS. The only build warning is Xcode skipping App Intents
  metadata because the target does not depend on AppIntents; FarrierFlow ships
  no App Intents. The current full UI log contains only the simulator runtime's
  duplicate Web accessibility-loader notice and no invalid-frame warning.
- App icons and launch presentation: PASS — compiled app icons and asset catalog
  are present; the frozen Release binary launched at 1320 x 2868 and visually
  matched the accepted semantic palette and onboarding layout.

## Screenshots

The six primary assets in `docs/release/screenshots/6.9-inch/` are 1320 x 2868
RGB JPEGs without alpha. They were captured from the frozen behavior on the
iPhone 17 Pro Max using deterministic fictional data and contain no testing
labels, customer data, or Apple account data. Visual review passed for
FarrierFlow Pro, Today run sheet, Schedule, Atlas history, invoice 0148, and
read-only retained records. The historical 6.3-inch set is superseded.

Repository presence does not imply App Store Connect upload. The portal still
contained seven stale custom 6.9-inch images at the last live read-only check.

## Archive evidence

- Archive path: `/tmp/FarrierFlow-1.0-RC.xcarchive`.
- `xcodebuild archive` from RC SHA: PASS.
- Archive app signature and designated requirement: PASS.
- Bundle/version/build/minimum OS/device family: PASS —
  `com.farrierflow.yusufcan.FarrierFlow`, 1.0 (1), iOS 18.0, iPhone family 1.
- App and RevenueCat privacy manifests: PASS.
- RevenueCat linkage/resources: PASS — no dynamic RevenueCat framework,
  RevenueCat resource bundle present.
- Test/debug/StoreKit resource exclusion: PASS.
- Archive binary SHA-256:
  `bf0e08d315f9f09a40af2046497078917c70a612d6f8a8ab8672f97ec2393ea3`.
- Source integrity after archive: PASS — no tracked application/project change
  relative to the immutable RC SHA.

The archive carries the automatic Apple Development profile used to create the
Xcode archive. A non-uploading App Store Connect export then failed with
`No Accounts` and `No profiles for 'com.farrierflow.yusufcan.FarrierFlow' were
found`. This was not retried unchanged.

## External gates

Every external gate has one status below.

| External gate | Status | Evidence or exact next operator step |
| --- | --- | --- |
| App Store Connect version 1.0 draft exists; build 1 unused | PASS | Live Safari check on 2026-09-05 showed Prepare for Submission, no version build, and TestFlight No Builds. |
| Privacy and Support URLs publicly reachable and source-faithful | PASS | Both returned HTTP 200 on 2026-09-05 and matched local-first, RevenueCat, read-only, and support-mailbox behavior. |
| App Privacy Purchase History disclosure published | PASS | Published 2026-08-28 for App Functionality and Analytics, not linked, no tracking; current binary remains consistent. |
| Monthly/yearly products and FarrierFlow Pro configuration | PASS | Both products are Ready for Review, use the approved U.S. prices/trials, and are connected to RevenueCat entitlement `pro` and the current Offering. |
| Xcode Organizer Validate App / App Store distribution profile | NOT YET VERIFIED | Unlock the Mac, sign in to the Apple ID under Xcode Settings > Accounts, obtain/refresh App Store distribution signing, then run Organizer Validate App for `/tmp/FarrierFlow-1.0-RC.xcarchive`; retain the validation success report. |
| Upload and processing of build 1 | NOT YET VERIFIED | After validation, upload the frozen archive and wait for build 1 to finish processing; retain Organizer upload success and App Store Connect processed-build evidence. |
| Attach processed build 1 to version 1.0 | NOT YET VERIFIED | Select only the processed 1.0 (1) build in the version draft and retain the saved build-section screenshot. |
| Replace stale portal screenshots with the exact six RC assets | NOT YET VERIFIED | In the English (U.S.) 6.9-inch slot, remove the seven stale images and upload the six files under `docs/release/screenshots/6.9-inch/` in numeric order; verify 6.5-inch inheritance and create 6.3-inch assets only if required. |
| Attach FarrierFlow Pro plus monthly/yearly subscriptions to version 1.0 | NOT YET VERIFIED | Add the existing group/products to the draft's In-App Purchases and Subscriptions section and retain the saved attachment evidence. |
| Copyright, review contact, Content Rights, release behavior, age rating, and source-backed metadata complete | NOT YET VERIFIED | The live draft had blank copyright and review-contact fields and incomplete Content Rights/release confirmation. Enter only owner-confirmed contact/copyright facts; recheck the already-saved metadata and 4+ age rating. |
| Agreements banner cleared; free download; U.S. subscription availability; Mac/Vision exclusion | NOT YET VERIFIED | Re-open the live portal after unlock and capture current saved state. Do not mutate agreements, legal, tax, banking, pricing, or availability. |
| Sign-in Required is false | PASS | Live version-draft evidence records the account-free review setting. |
| TestFlight install and complete physical-iPhone workflow | NOT YET VERIFIED | Bring physical iPhone `00008120-0016043C0138C01E` online, install processed build 1, record tester/date/device/OS, and exercise onboarding through next appointment, PDF/share, photos, background/foreground, relaunch, Light/Dark, keyboard, touch targets, and outdoor legibility. |
| Sandbox purchase, entitlement activation, Restore, loss to read-only, and reactivation | NOT YET VERIFIED | On processed build 1, use an Apple sandbox tester and retain device video/screenshots plus RevenueCat customer-event evidence for all five transitions. |
| Apple server-notification receipt in RevenueCat | NOT YET VERIFIED | Retain the RevenueCat dashboard event/log tied to the sandbox lifecycle run. |
| Support mailbox receive-and-reply operation | NOT YET VERIFIED | Send a fresh external message to `farrierflow.support@gmail.com`, receive it, reply from that address, and retain redacted sent/received evidence. |
| Stop before Add for Review / Submit for Review | PASS | Neither action was taken; version remains a draft. |

The Safari session initially displayed the authorized FarrierFlow TestFlight
page and confirmed **No Builds**, but navigating to Distribution redirected to
Apple sign-in. No credentials were requested or entered and no portal state was
changed. Reauthenticate the Apple account before performing the remaining
draft-only portal steps.

## Must fix before App Review

1. Restore an authenticated Xcode account/distribution profile and obtain a
   successful Organizer validation for the frozen archive.
2. Upload build 1, wait for processing, and attach that exact build to version
   1.0.
3. Replace the stale portal screenshots with the exact six certified 6.9-inch
   assets and attach the existing subscription group/products.
4. Complete only the missing owner-supplied copyright, review contact, Content
   Rights, and release-behavior fields; reverify agreements and saved
   availability without changing legal, financial, price, or market scope.
5. Complete the physical-device/TestFlight purchase lifecycle, server
   notification, full workflow, and support-mailbox checks with evidence.

No speculative polish, schema change, feature expansion, pricing change, or
architecture refactor is a 1.0 blocker.

APP STORE 1.0 VERDICT: NO-GO
