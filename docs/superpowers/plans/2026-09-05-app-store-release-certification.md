# FarrierFlow 1.0 App Store Release Certification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Certify the current FarrierFlow `main` branch as a frozen, evidence-backed App Store 1.0 release candidate without adding non-essential MVP scope.

**Architecture:** Preserve the existing local-first SwiftData architecture, RevenueCat subscription boundary, read-only entitlement fallback, semantic design system, and current product workflows. Treat this as release certification and blocker remediation rather than product expansion.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, iOS 18+, Xcode 26.x, XCTest/Swift Testing, XCUITest, RevenueCat Purchases iOS, StoreKit, Apple privacy manifests.

**Specs:** `docs/superpowers/specs/2026-08-10-v1-revenue-release-design.md` and `docs/superpowers/specs/2026-09-03-color-palette-revamp-design.md`

## Scope and verified baseline

- Work only in `/Users/prometheus/Desktop/Folders/FarrierFlow`; preserve all existing untracked `.impeccable/`, `.superpowers/`, and `output/` content.
- Baseline `main` and `origin/main` at `827a4f6d336793011cf9a13dcb08a20dd2b048a4`; certification delta is `7d7f44b..827a4f6`.
- Exclude `FarrierFlow.storekit` from shipping products while retaining it as the shared scheme's local StoreKit configuration.
- Produce six truthful 6.9-inch RC screenshots. Keep 6.3-inch conditional on live portal requirements.
- Prepare the App Store Connect draft but do not Add for Review or Submit for Review.
- Do not change public APIs, SwiftData schema, entitlement rules, prices, or product scope unless a reproduced release blocker requires it.

## Task 1: Baseline and external-state preflight

- [ ] Capture Git status, local/remote SHAs, release delta, Xcode/Swift versions, package resolution, destinations, signing identities, devices, and simulators.
- [ ] Inspect App Store Connect read-only. Retain build 1 if unused; otherwise use the smallest unused build number before testing. If authentication is unavailable, mark the portal/build-number gate `NOT YET VERIFIED`.
- [ ] Record marketing version, build number, deployment target, bundle identifier, RevenueCat version, and candidate SHA.

```zsh
REPO=/Users/prometheus/Desktop/Folders/FarrierFlow
cd "$REPO"
git fetch --prune origin
git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
git ls-remote --heads origin main
git log --oneline --decorate -12
git diff --stat 7d7f44b..HEAD
git diff --name-status 7d7f44b..HEAD
xcodebuild -version
swift --version
xcodebuild -list -project FarrierFlow.xcodeproj
xcodebuild -showdestinations -project FarrierFlow.xcodeproj -scheme FarrierFlow
xcrun xctrace list devices
```

## Task 2: Confirmed release blocker and source contracts

- [ ] Add `Resources/FarrierFlow.storekit` to the app target's synchronized-group membership exceptions; keep the scheme reference.
- [ ] Verify local StoreKit-backed subscription UI tests still work and Debug/Release products contain no `.storekit`.
- [ ] Reconcile product, roadmap, architecture, data, design, governing specs, and `docs/release/` status with current implementation and evidence.
- [ ] Make `app-store-metadata.md` and `submission-checklist.md` agree about screenshot, upload, build, subscription, TestFlight, and portal status.
- [ ] Verify product identifiers/prices/trials, yearly-first presentation, privacy manifests, required-reason APIs, local-first claims, absence of tracking/advertising SDKs, and redacted secret scan.
- [ ] Verify the live privacy and support URLs. Treat mailbox monitoring/reply ability as external evidence.

## Task 3: Serial current-HEAD certification

- [ ] Run full `FarrierFlowTests` on iOS 18 and iOS 26.
- [ ] Run full `FarrierFlowUITests` on iOS 26.
- [ ] Run the focused owner, connected-records, visit, invoice, next-appointment, subscription, read-only, and accessibility suites on iOS 18.
- [ ] Run Release simulator builds on both OS versions.
- [ ] Extract exact discovered/executed/passed/failed/skipped counts from each xcresult and record subsystem results.
- [ ] Compile localization, lint plists/manifests/StoreKit JSON, run `git diff --check`, and classify every warning.

```zsh
CERT_DIR=$(mktemp -d /tmp/farrierflow-cert.XXXXXX)
PROJECT="$REPO/FarrierFlow.xcodeproj"
IOS18='platform=iOS Simulator,id=02DB4E38-DF46-4F30-A8C8-C4D4DF46FDA4'
IOS26='platform=iOS Simulator,id=A9501C1D-4747-4310-8F2B-F0587E0E30C6'
COMMON=(-project "$PROJECT" -scheme FarrierFlow -parallel-testing-enabled NO -maximum-parallel-testing-workers 1)

xcodebuild test "${COMMON[@]}" -destination "$IOS18" -only-testing:FarrierFlowTests -resultBundlePath "$CERT_DIR/units-ios18.xcresult"
xcodebuild test "${COMMON[@]}" -destination "$IOS26" -only-testing:FarrierFlowTests -resultBundlePath "$CERT_DIR/units-ios26.xcresult"
xcodebuild test "${COMMON[@]}" -destination "$IOS26" -only-testing:FarrierFlowUITests -resultBundlePath "$CERT_DIR/ui-ios26.xcresult"
xcodebuild test "${COMMON[@]}" -destination "$IOS18" \
  -only-testing:FarrierFlowUITests/OwnerSetupUITests \
  -only-testing:FarrierFlowUITests/ConnectedRecordsUITests \
  -only-testing:FarrierFlowUITests/VisitCompletionUITests \
  -only-testing:FarrierFlowUITests/InvoiceFlowUITests \
  -only-testing:FarrierFlowUITests/NextAppointmentFlowUITests \
  -only-testing:FarrierFlowUITests/SubscriptionFlowUITests \
  -only-testing:FarrierFlowUITests/SubscriptionReadOnlyUITests \
  -only-testing:FarrierFlowUITests/EditorAccessibilityUITests \
  -resultBundlePath "$CERT_DIR/ui-focused-ios18.xcresult"
xcodebuild build "${COMMON[@]}" -configuration Release -destination "$IOS18"
xcodebuild build "${COMMON[@]}" -configuration Release -destination "$IOS26"

LOC_DIR=$(mktemp -d /tmp/farrierflow-localization.XXXXXX)
xcrun xcstringstool compile --dry-run --output-directory "$LOC_DIR" FarrierFlow/Resources/Localizable.xcstrings
plutil -lint FarrierFlow/Info.plist
plutil -lint FarrierFlow/PrivacyInfo.xcprivacy
jq empty FarrierFlow/Resources/FarrierFlow.storekit
git diff --check
```

For failures: capture the exact evidence, classify the cause, reproduce repository defects, add the smallest practical regression test, make the minimum fix, rerun the focused gate, then rerun every affected release gate. Never skip or weaken a release check.

## Task 4: Behavioral, visual, PDF, photograph, and screenshot acceptance

- [ ] Complete the fictional owner journey on the primary iOS 26 simulator: onboarding, business, client, location, horse, appointment, visit, hoof photo, work items, completion, invoice, PDF/share, payment, next appointment, dismissal, relaunch, and persistence.
- [ ] Verify Light/Dark, accessibility Dynamic Type, VoiceOver order/labels, Reduce Motion, keyboard avoidance, touch targets, contrast, and orange rarity.
- [ ] Inspect invoice PDF content/pagination/formatting/totals/paid state/shareability and photograph persistence/deletion/missing-file behavior.
- [ ] Capture six 1320x2868 RGB/no-alpha JPEGs from the frozen source with deterministic fictional fixtures: Pro, Today, Schedule, horse history/photos, invoice, and read-only records.
- [ ] Store them in `docs/release/screenshots/6.9-inch/`, verify them with `sips`, compare to Release UI, and mark the old 6.3-inch set superseded.

## Task 5: Freeze and signed archive

- [ ] Stage only approved project/configuration fixes, regression tests, release documentation, and final screenshots. Audit the staged diff and exclude all pre-existing untracked artifacts.
- [ ] Commit locally as `chore(release): certify FarrierFlow 1.0 release candidate`; do not push. Record the SHA as the immutable application RC.
- [ ] Archive that SHA for generic iOS with automatic signing and validate it in Organizer.
- [ ] Inspect signature, entitlements, identifiers/versions, deployment/device family, icons/launch assets, app and RevenueCat manifests, RevenueCat linkage/resource bundle, and absence of test/debug/StoreKit resources or secrets.
- [ ] Any later application-source change invalidates the archive. Evidence-only documentation commits may reference but cannot redefine the RC SHA.

```zsh
RC_SHA=$(git rev-parse HEAD)
ARCHIVE_PATH=/tmp/FarrierFlow-1.0-RC.xcarchive
xcodebuild archive -project "$PROJECT" -scheme FarrierFlow -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE_PATH" -allowProvisioningUpdates
```

## Task 6: App Store draft and external acceptance

- [ ] Upload the validated archive and wait for processing; select it for version 1.0.
- [ ] Upload the six 6.9-inch screenshots. Remove stale custom overrides so smaller displays inherit them; create a separate 6.3-inch set only if required.
- [ ] Complete only source-backed metadata, URLs, copyright, review contact, Content Rights, release behavior, age rating, build, and subscription attachments.
- [ ] Verify agreement banner, free download, US subscription availability, Mac/Vision Pro exclusions, privacy disclosure, and sign-in state without changing legal, banking, tax, agreements, pricing, or availability.
- [ ] Stop in draft before Add for Review or Submit for Review.
- [ ] On physical TestFlight, verify camera/photos, full workflow, PDF/share, lifecycle/relaunch, Light/Dark, keyboard, touch targets, and outdoor legibility.
- [ ] Verify Apple sandbox purchase, RevenueCat activation, restore, entitlement loss to read-only, reactivation, server notifications, and support mailbox receive/reply.
- [ ] Mark each inaccessible external gate `NOT YET VERIFIED` with exact operator steps, expected result, and evidence required.

## Task 7: Final ship-readiness report

- [ ] Create or update `docs/release/ship-readiness.md` with the RC SHA, versions, exact test counts, subsystem results, localization/privacy/icon/build/archive/screenshot/website/diff evidence, and every external gate marked `PASS`, `FAIL`, or `NOT YET VERIFIED`.
- [ ] Separate genuine pre-review blockers from safe post-1.0 improvements.
- [ ] End with exactly `APP STORE 1.0 VERDICT: GO` only if every local and external gate passes; otherwise end with exactly `APP STORE 1.0 VERDICT: NO-GO` and the smallest conditions needed for GO.

## Assumptions and boundaries

- Six current 6.9-inch screenshots are primary; 6.3-inch output is conditional.
- Portal authorization covers draft preparation, build/TestFlight and screenshot uploads, and source-backed attachments—not review submission.
- The RC commit remains local unless push authorization is separately provided.
- Existing meaningful workspaces retain read-only access without entitlement; fresh empty workspaces retain approved onboarding/paywall behavior.
- Use no production/customer data. Do not perform schema migration, feature expansion, price change, legal/banking/tax mutation, or review submission.
