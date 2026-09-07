# FarrierFlow 1.0 Ship Readiness

**Certification date:** 2026-09-05

**Last updated:** 2026-09-06

**Immutable application RC:** `b1d4a8ea55fb14ce56b81a2c0fba73da5b5a8611`

**Superseded build 1 RC:** `cee7a12381a22b6bf95632368508d2df3ba9cd61`

**Baseline before certification:** `827a4f6d336793011cf9a13dcb08a20dd2b048a4`

**Uncertified release delta reviewed:** `7d7f44b..827a4f6` (100 files)

**Version:** 1.0 (corrected replacement candidate build 2)

**Bundle identifier:** `com.farrierflow.yusufcan.FarrierFlow`

**Deployment / device family:** iOS 18.0+, iPhone only

**RevenueCat:** Purchases iOS 5.87.1 at revision
`b65cae4f227be800c57cb9700dbd94f2aa5409b2`

## Verdict summary

The original frozen source remains a valid record of the completed certification
matrix, successful Organizer validation, and upload/processing of version 1.0
build 1. On 2026-09-06, the owner authorized four release UI corrections on
`main`: invoice toolbar actions, a floating full-width Next Appointment action,
inline-large root titles with preserved spacing, and an explicit Hoof Photos row
label. Because these are application-source changes after the freeze, build 1 is
superseded for submission. The corrected worktree passes focused UI and model
coverage, a Release build, localization, bundle inspection, and diff checks and
is frozen at immutable RC `b1d4a8ea55fb14ce56b81a2c0fba73da5b5a8611`.
Its signed archive also passed local inspection. The
seven corrected screenshots are now uploaded and inherited by the 6.5-inch
slot. Physical-device purchase lifecycle,
and support-mailbox operation remain open, keeping the verdict at NO-GO.

## Post-RC source corrections — 2026-09-06

- Invoice detail: PASS — Mark as Paid, Share, and More are top-right toolbar
  actions; Mark as Unpaid and Delete Invoice are destructive actions inside
  More. The focused iOS 18 toolbar regression passed 1/1.
- Next Appointment: PASS — Continue is full width, pinned above the safe area,
  and floats directly on the screen background rather than inside a Form
  section. The focused iOS 26 pinned-action regression passed 1/1.
- Root navigation and spacing: PASS — Today, Schedule, and Clients use
  `inlineLarge` at regular text sizes, fall back to `inline` at accessibility
  sizes, retain an 8-point toolbar/content gap, and use the existing 16-point
  standard rhythm between major content groups. Focused iOS 26 coverage passed
  3/3, including Accessibility XXXL.
- Visit photographs: PASS — Atlas and every other Visit horse now expose one
  visible Hoof Photos row label followed by its count. The focused iOS 26
  showcase regression passed 1/1.
- Next Appointment persistence/reopen: PASS — the complete iOS 26.5 UI suite
  passed 2/2 after its harness was updated to use destination-based navigation
  and to leave compact DatePicker override coverage to the model boundary.
  `NextAppointmentAssistantModelTests` passed all 9 declared tests on iOS 18.0
  (14 parameterized executions, no failures or skips), including manual date
  and time overrides. The native virtual Toggle activation issue observed on
  the iOS 18 simulator is classified as an XCTest/simulator interaction issue,
  not a reproduced product or persistence defect.
- Release simulator build for candidate build 2 on iOS 26.5: PASS. The built
  app reports 1.0 (2), contains both privacy manifests, and contains no
  `.storekit` resource. Localization catalog compilation, plist/StoreKit
  validation, and `git diff --check`: PASS.

No schema, domain model, entitlement policy, pricing, privacy, onboarding,
RevenueCat, StoreKit, or public API behavior changed. The prior full
certification evidence remains applicable to those unchanged boundaries.

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

## Superseded-RC automated certification

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

The six historical primary assets in `docs/release/screenshots/6.9-inch/` are
superseded by the post-correction screenshot design. The current seven Figma
exports are in `/Users/prometheus/Desktop/Updated-Screenshots-Figma-Export`;
each is a 1320 x 2868 JPEG with `hasAlpha: no`. Seven files are intentional
because two adjacent product-page images form one continuous visual. App Preview
is intentionally omitted; it is optional and is not a release blocker.

Live App Store Connect inspection on 2026-09-06 confirmed all seven corrected
images in the 6.9-inch slot, in this saved order: Hero, Cats-You-Meet,
Memories-You-Keep, Photo-To-Card, Atlas, Frame-1, and Frame. The 6.5-inch slot
shows **Using 6.9-inch Display** and inherits all seven. No additional slot or
resized asset is currently required.

## Archive evidence

### Corrected build 2 RC

- Immutable RC SHA: `b1d4a8ea55fb14ce56b81a2c0fba73da5b5a8611`.
- Archive path: `/tmp/FarrierFlow-1.0-build2-RC.xcarchive`.
- `xcodebuild archive` from the exact RC SHA: PASS.
- Archive app signature and designated requirement: PASS.
- Bundle/version/build/minimum OS/device family: PASS —
  `com.farrierflow.yusufcan.FarrierFlow`, 1.0 (2), iOS 18.0, iPhone family 1.
- App and RevenueCat privacy manifests: PASS.
- RevenueCat linkage/resources: PASS — no dynamic RevenueCat framework,
  RevenueCat resource bundle present.
- Test/debug/StoreKit resource exclusion: PASS.
- Archive binary SHA-256:
  `39e5a5270152d3c27a62e6fd7f4663eaea18e4eb8c4768a341216204e6c42628`.
- Source integrity after archive: PASS — no tracked application/project change
  relative to the immutable RC SHA.
- App Store validation/upload: PASS — after the owner restored Xcode's Apple
  Account session, the unchanged archive passed App Store analysis and upload.
  Xcode reported `Upload succeeded` and `** EXPORT SUCCEEDED **`; log:
  `/tmp/farrierflow-build2-upload-retry.log`.
- Processing and export compliance: PASS — live TestFlight displayed build 2
  as Ready to Submit after the source-backed “None of the algorithms mentioned
  above” answer was saved.
- Version attachment: PASS — live version 1.0 draft displayed build 2 / version
  1.0 and the saved build section after attachment.
- Physical TestFlight clean launch and subscription-plan load: PASS — owner
  evidence from iPhone 14 Pro on iOS 26.6.1 showed the clean first-run flow
  reaching `FarrierFlow Pro`, both monthly and yearly products, yearly selected
  by default, and the eligible two-week free trial. The app displayed
  `$14.99/month` and `$119.99/year`; Apple's TestFlight confirmation sheet
  displayed `₺5,999.99/year` for the Turkish storefront. RevenueCat documents
  [this split](https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store)
  as a sandbox/TestFlight metadata quirk, and source inspection confirms the
  shipping client passes through `Package.localizedPriceString`.
- Yearly sandbox purchase and entitlement activation: PASS — on the same
  physical TestFlight installation, the app showed `Completing Purchase...`,
  Apple's `You're all set` confirmation appeared after about two seconds, and
  FarrierFlow routed to Today about two seconds later. RevenueCat's sandbox
  customer profile independently records the matching Turkish
  `INITIAL_PURCHASE` for `FarrierFlow Yearly`, entitlement ID `pro`, and an
  Active `FarrierFlow Pro` entitlement. RevenueCat records the period as
  `NORMAL`; trial activation is therefore not inferred.
- Physical camera and photograph persistence: PASS — the owner captured one
  image through Atlas → Hoof Photos on the physical iPhone, saved Visit
  progress, and reopened the Visit. The supplied device evidence shows the
  persisted Atlas Hoof Photos count of `1`.
- Physical Visit completion and follow-up projection: PASS — the owner
  completed the Visit with Atlas Serviced and Beacon Not Serviced. The Next
  Appointment assistant preserved Willow Creek Stables, proposed Atlas at its
  six-week interval, selected Atlas, and did not select Beacon.
- Physical next-appointment save: PASS — the owner continued from the assistant
  and saved the follow-up. Schedule shows the September 7 Willow Creek
  appointment as Completed and the October 19 appointment persisted with Atlas
  only.
- Physical invoice generation: PASS — Invoice 0001 was generated from the
  completed September 7 Visit. Device evidence shows Unpaid status, Jordan
  Ellis, Willow Creek Stables, Atlas → Full Set, `$220.00` amount due, the
  expected 14-day due date, and paid/share/more toolbar actions.
- Physical PDF/share and background/foreground: PASS — the owner shared Invoice
  0001 to Files, opened the generated one-page PDF, and returned to FarrierFlow.
  Device evidence shows complete unclipped content, matching totals and
  snapshots, a page footer, and the responsive invoice after returning.

### Superseded build 1 RC

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
Xcode archive. The owner authenticated the Apple Developer account in Xcode and
reported a successful Organizer **Validate App** result for this exact archive
on 2026-09-05. An upload-only `xcodebuild -exportArchive` then completed with
`Upload succeeded` and `** EXPORT SUCCEEDED **`; App Store Connect subsequently
displayed version 1.0 build 1 under TestFlight. The upload log is
`/tmp/farrierflow-cert.rO0al7/upload.log`.

## External gates

Every external gate has one status below.

| External gate | Status | Evidence or exact next operator step |
| --- | --- | --- |
| App Store Connect version 1.0 draft exists | PASS | Live Safari inspection on 2026-09-06 showed version 1.0 in Prepare for Submission with corrected build 2 attached. Build 1 remains superseded. |
| Privacy and Support URLs publicly reachable and source-faithful | PASS | Both returned HTTP 200 on 2026-09-05 and matched local-first, RevenueCat, read-only, and support-mailbox behavior. |
| App Privacy Purchase History disclosure published | PASS | Published 2026-08-28 for App Functionality and Analytics, not linked, no tracking; current binary remains consistent. |
| Monthly/yearly products and FarrierFlow Pro configuration | PASS | Both products are Ready for Review, use the approved U.S. prices/trials, and are connected to RevenueCat entitlement `pro` and the current Offering. |
| Xcode Organizer Validate App / App Store distribution profile | PASS | Owner reported successful Organizer validation of `/tmp/FarrierFlow-1.0-RC.xcarchive` on 2026-09-05. |
| Upload and processing of superseded build 1 | PASS | Exact frozen archive upload succeeded at 2026-09-05 14:58 local time; App Store Connect displayed TestFlight version 1.0 build 1. The owner reports that its export-compliance answer was saved. |
| Export compliance for build 1 | PASS | Owner reported saving the source-backed answer on 2026-09-06. The replacement build must receive the same source-backed answer after processing. |
| Freeze corrected build 2 | PASS | Approved source/configuration/tests/docs were committed locally at immutable application RC `b1d4a8ea55fb14ce56b81a2c0fba73da5b5a8611`; no push was performed and pre-existing untracked artifacts were excluded. |
| Archive and locally inspect corrected build 2 | PASS | `/tmp/FarrierFlow-1.0-build2-RC.xcarchive` was created from the exact RC SHA and passed version, signature, entitlement, privacy, RevenueCat, icon, artifact-exclusion, and source-integrity inspection. |
| Validate, upload, process, export compliance, and attach corrected build 2 | PASS | The unchanged build 2 archive passed App Store analysis and upload; live TestFlight showed build 2 Ready to Submit after export compliance was saved, and live version 1.0 displayed build 2 attached. Build 1 remains superseded. |
| Internal TestFlight group and corrected-build availability | PASS | On 2026-09-07, live App Store Connect showed internal group `FarrierFlow 1.0 RC` with automatic future-build distribution disabled, only build 1.0 (2) in `Ready to Test` state, and the Account Holder as its sole tester with status `Invited`. No install or physical-device acceptance is inferred. |
| Replace stale portal screenshots with the seven corrected 6.9-inch assets | PASS | Live Safari inspection on 2026-09-06 showed all seven corrected JPEGs in saved order in the 6.9-inch slot; the 6.5-inch slot inherits the same seven. |
| App Preview | PASS | The live draft shows 0 of 3 previews. Owner deliberately omitted this optional media; no preview is required for submission. |
| Attach FarrierFlow Pro plus monthly/yearly subscriptions to version 1.0 | PASS | The live Draft Submission contains three ready items: FarrierFlow Pro subscription group, FarrierFlow Monthly, and FarrierFlow Yearly. No Add for Review or Submit action was taken. |
| Copyright, review contact, Content Rights, and release behavior complete | NOT YET VERIFIED | Live Safari inspection on 2026-09-06 showed copyright and all four review-contact fields blank; Content Rights still says Set Up. Automatic release is selected, but owner intent is not established. Supply only those owner-confirmed facts and choose the intended release behavior. |
| Age rating | PASS | Live App Information shows 4+ in 172 countries/regions and global 4+ for operating systems earlier than version 26. |
| U.S. availability; Mac/Vision exclusion | PASS | Live Pricing and Availability shows 1 available country (United States), Mac availability off, and version 1.0 incompatible/unavailable on Vision Pro. |
| Agreements and free-download state | PASS | Live Business inspection on 2026-09-06 showed both Free Apps and Paid Apps agreements Active with no review banner. Pricing shows the existing current price schedule with no paid amount/proceeds; no pricing state was changed. |
| Sign-in Required is false | PASS | Live version-draft evidence records the account-free review setting. |
| Physical camera and hoof-photo persistence | PASS | The owner captured a photo through Atlas → Hoof Photos on the physical TestFlight build, saved progress, reopened the Visit, and supplied device evidence showing the persisted photo count of `1`. |
| Physical Visit completion and next-appointment projection | PASS | Device evidence shows the completed Atlas/Beacon outcomes feeding the Next Appointment assistant: Willow Creek Stables is retained, Atlas is selected at its six-week suggestion, and unserviced Beacon is excluded. |
| Physical next-appointment save and persistence | PASS | Schedule shows the original September 7 Willow Creek appointment as Completed and the saved October 19 follow-up containing only Atlas, matching the assistant selection. |
| Physical invoice generation | PASS | Device evidence shows Invoice 0001 generated from the completed Visit with correct Unpaid status, Jordan Ellis and Willow Creek snapshots, Atlas Full Set line item, `$220.00` amount due, 14-day due date, and top-right paid/share/more actions. |
| Physical invoice PDF/share and background/foreground return | PASS | The owner shared Invoice 0001 to Files, opened the one-page PDF, and returned to the responsive invoice. Evidence shows complete unclipped invoice content, matching totals and snapshots, and page footer `Invoice 0001 • 1`. |
| TestFlight install and complete physical-iPhone workflow | NOT YET VERIFIED | On 2026-09-07, the owner installed build 1.0 (2) on an iPhone 14 Pro running iOS 26.6.1, deleted the prior app copy, and reinstalled from TestFlight before opening. Clean onboarding, connected records, physical camera/photo persistence, Visit completion, next-appointment save, invoice generation, PDF/share, and background/foreground return are evidenced. Exercise and evidence the remaining payment, relaunch persistence, Light/Dark, keyboard, touch targets, and outdoor legibility before this combined gate can pass. |
| Yearly sandbox purchase and `pro` entitlement activation | PASS | Physical-device screenshots show the TestFlight purchase flow, Apple success confirmation, and automatic route to Today. RevenueCat sandbox data records the matching Turkish `INITIAL_PURCHASE` for `FarrierFlow Yearly`, entitlement ID `pro`, and Active `FarrierFlow Pro` access. |
| Monthly sandbox purchase and trial behavior | NOT YET VERIFIED | Exercise the monthly product with an eligible Apple sandbox tester and retain the Apple confirmation plus matching RevenueCat customer-event evidence. The completed yearly event has period type `NORMAL`, so it does not prove introductory-trial behavior. |
| Restore Purchases | NOT YET VERIFIED | Perform Restore Purchases after creating meaningful records and retain the device result plus matching RevenueCat state. |
| Entitlement loss, retained read-only records, and reactivation | NOT YET VERIFIED | After the full workflow and persistence checks, allow or force a real sandbox entitlement transition, verify retained records are read-only, then reactivate and retain device plus RevenueCat evidence. |
| Apple server-notification receipt in RevenueCat | NOT YET VERIFIED | Retain the RevenueCat dashboard event/log tied to the sandbox lifecycle run. |
| Support mailbox receive-and-reply operation | NOT YET VERIFIED | Send a fresh external message to `farrierflow.support@gmail.com`, receive it, reply from that address, and retain redacted sent/received evidence. |
| Stop before Add for Review / Submit for Review | PASS | Neither action was taken; version remains a draft. |

## Must fix before App Review

1. Complete only the missing owner-supplied copyright, review contact, Content
   Rights, and release-behavior fields without changing legal, financial,
   price, or market scope.
2. Complete the physical-device/TestFlight purchase lifecycle, server
   notification, full workflow, and support-mailbox checks with evidence.

No speculative polish, schema change, feature expansion, pricing change, or
architecture refactor is a 1.0 blocker.

APP STORE 1.0 VERDICT: NO-GO
