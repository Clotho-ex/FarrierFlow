# FarrierFlow UI/UX audit and refinement

Date: 2026-10-22. Scope: the current native iPhone application, including the unreleased backup/sync UI. This audit preserves the Field Book design and existing business rules.

## Preserved checkpoint

- Branch: `codex/solo-backup-sync`.
- Checkpoint: `8685249d3f8a6107808689847df05c10af70de7e`.
- Commit: `checkpoint: preserve current UI before comprehensive UX refinement`.
- All 25 legitimate pending application/documentation/test files were reviewed and committed. The working tree was verified clean before the audit. No secrets or generated artifacts were included. No push, reset, amend, migration, dependency change, or production service operation was performed.

## Product and design assessment

Native platform conformance passes the source review: four native tabs, independent NavigationStacks, system sheets/forms/selectors, native toolbar materials, semantic colors/type, and restrained grouped surfaces. The product already has a coherent operational identity. The recent Clients, appointment form, and Schedule hierarchy improvements are retained.

The useful improvements concern finding records, acting on contact/arrival information, retaining unfinished input, and making safe service/sync decisions. Further decoration or a new navigation structure would not address those problems.

## Prioritized findings

No P0 was identified in this UI-focused audit. Existing data-integrity, financial, migration, sync, and persistent reopening tests are part of validation; this is not a claim that all possible data-loss defects have been ruled out.

| Priority | Finding and field impact | Focused change | Verification |
| --- | --- | --- | --- |
| P1 | An initial Clients/Service Locations fetch failure looks like an empty business after the alert is dismissed. | Explicit loading/failure state, native Retry, retained last successful rows and a retry action in the alert. Creation waits for a successful initial read. Preserve unchanged client snapshots during ordinary synchronous refreshes. | Injected first-load failure, successful empty retry, failed populated refresh and recovery tests in both feature models; native normal directory regression flows. |
| P1 | Active Visit omits owner/handling context, so same-named horses at a shared barn are ambiguous. | Show saved owner and existing safety notes in the current horse section during active work. Keep correction/history and the editable draft unchanged. | Duplicate-name/different-owner model regression, clean dirty-state baseline, largest-text active-work screenshot and existing service/completion/relaunch flows. |
| P1 | Clients requires scrolling the full directory even when the farrier knows the horse or a phone fragment. | Native local search across saved client name/contact information and actual associated horse names. Prefetch the horse relationship once for projection; normalize phone punctuation. Preserve rows, counts, detail routes, and creation. | Search rules and saved-relationship tests; native search → detail, no-result and recovery states, largest text/dark mode. |
| P1 | Invoices requires scrolling to answer a customer's question about a specific invoice. | Native search by recorded client name and issued invoice number within the existing All/Unpaid filter. Preserve the independent local-history entry. | Native client/number search → invoice/PDF controls; existing paid/unpaid, read-only and archive workflows. |
| P1 | New/edit customer, horse, location, appointment and service sheets permit an accidental downward gesture to lose input. | Compare the current draft with its initial displayed draft and disable interactive dismissal while changed. Explicit Save and Cancel retain their behavior; opening nested creation does not reset the comparison. | Drag-to-dismiss attempts across all five creation forms, nested cancellation and draft retention; existing scheduling/editing/relaunch tests. |
| P1 | Appointment phone numbers and saved arrival addresses cannot be acted on where the farrier is reading them. | Neutral native call links on appointment horses; native Maps directions from Appointment, Stop Details and Service Location. Use saved values and safely encode URL recipients/destinations. | URL encoding tests, accessibility action roles/labels and 44 pt hit areas in normal and largest-text layouts. Native system handoff is requested only on activation. |
| P1 | Start Visit follows every horse/contact row, so the primary barn-work action falls below the first screen on a two-horse appointment. | Move the existing action directly beneath the appointment summary, preserving its guard, action and styling. | Initial-screen hittability and screenshots in light mode and largest-text dark mode; existing start/resume/completion workflows. |
| P1 | Visit service selection exposes creation only when no eligible service exists, and replacement exposes no creation route. The farrier must leave work entry to add a different service. | Keep the catalog list and append its existing Create Service action. Created services add or replace exactly the targeted WorkItem, then return to the same visit draft. Add native Cancel to the presented Add Service selector. | Create while replacing, preserve the other horse's work, Save Progress and relaunch; existing add/replace/outcome/completion tests. |
| P1 | Sync review labels conflicts only as Client/Horse/etc. A phone-only conflict hides the unchanged customer name, making choices ambiguous. | Show saved record identities above conflict fields and on related-change disclosures. Resolve planned-service references to their service names; use exact IDs as a truthful fallback. Keep confirmation, choices, graph validation, journal/cursor and persistence unchanged. | Pure presentation and existing resolution tests; multiple phone-only conflicts in native review at normal and accessibility text sizes. |
| P2 | Location arrival notes, visit price overrides and payment details lack the keyboard dismissal controls already used by primary forms. | Add FocusState-backed native Done controls and interactive scroll dismissal. Give location notes and payment details persistent visible labels. Shorten the payment toolbar action to Record so its title remains readable; retain Record Payment as its accessibility label. | Keyboard hide without save/draft loss; existing owner setup, visit price and manual payment flows. |
| P2 | Service-selection name and amount remain in a horizontal layout at accessibility sizes. | Stack those two existing values at accessibility sizes using AnyLayout; preserve semantic typography, native rows and normal-size layout. | Large-text/dark and compact-device selection checks. |

## Screen and workflow coverage

Source review follows the real feature boundaries rather than applying a common new layout everywhere:

| Surface | What was reviewed | Decision |
| --- | --- | --- |
| Today and daily stops | Truthful ranking, active/scheduled/completed/empty states, deduplication, date boundaries, read-only notice, contextual invoice/payment actions. | Retain composition and existing transitions. Add directions only inside stop details. |
| Schedule and appointment cards | Real status/owner/planned-service relationships, populated list, bounded summaries and separate tab history. | Retain the checkpointed hierarchy. |
| New/Edit Appointment | Required location/time/horses, per-horse optional plans, direct nested creation, validation, defaults, keyboard and draft ownership. | Retain form; protect changed draft from swipe dismissal. |
| Stop and Appointment Details | Arrival context, status/next action, selection-independent records, phone and safety information, native shared editor. | Make existing phone/address values actionable. |
| Active Visit and completion | Per-horse outcomes/work, explicit Save Progress/Complete, incomplete guidance, clear-work confirmation, batch work, dirty dismissal and next-appointment handoff. | Preserve business logic; show existing owner/handling context and improve service creation/selection and price keyboard. |
| Clients and Client Detail | Horse counts, phone/email actions, long names/contact wrapping, Profile hierarchy, client-only actions, invoice eligibility. | Retain detail; add directory search, honest load recovery and draft protection. |
| Horse creation/edit/detail/history | Independent client/location relationships, contextual creation, relocation confirmation, interval/default service, safety notes, completed history and linked work. | Retain layout/relationships; protect changed editor draft. |
| Service Locations | List/detail, arrival information, Add Horse, move existing horse and relationship constraints. | Add honest load recovery, directions, labeled notes and keyboard handling; protect changed draft. |
| Services | Active/archive distinction, reusable catalog prices vs recorded work, edit/archive/delete and selection. | Preserve catalog behavior; keep creation reachable in visit selection. |
| Invoices and payments | Eligibility/selection, recorded snapshots, totals/dates, manual payment wording, reversals, PDF/share and read-only access. | Add search and payment keyboard handling. Do not change money or payment rules. |
| Business and Business Profile | Operations/settings/support grouping, real outstanding balance/monthly completed work, editable defaults and locked currency. | Retain structure and native destinations. |
| Subscription/onboarding | Store-supplied prices/trials, restore/manage, purchase cancellation/failure/loading, read-only records and interrupted setup. | Retain behavior and branding; deterministic tests exercise states. |
| Backup & Sync and recovery | Optional sign-in/free protection, offline retry, precise status/counts, local-only history/PDF, sign-out/deletion confirmation and conflict review. | Improve conflict identification; preserve all recovery and deletion semantics. |
| Help/About and secondary states | Native links, installed version, empty/error/retry states, destructive confirmations and no irrelevant global tools in record menus. | Retain. |

The six field scenarios map to existing end-to-end tests and the added regression tests: morning stop/resume; customer lookup and scheduling; barn work and per-horse services; completion/invoice/manual payment; horse history and invoice lookup; business/catalog/profile/backup management.

## Validation evidence

Before refinement, the full iOS 26 unit/integration suite passed: 858 functions (1,010 successful parameterized executions), one existing physical-device-only file-protection skip, no failures. Result: `/tmp/ff-ux-audit-baseline26.xcresult`.

Simulator evidence is distinct from physical-device, live Apple purchase/sign-in, and hosted sync acceptance. Screenshots validate static appearance; they do not establish animation smoothness or outdoor hardware performance.

- Full iOS 26 build/unit/integration/UI run: `/tmp/ff-ux-final-integration26.xcresult`, exit 65. All 866 unit/integration functions passed (1,018 successful parameterized executions), one existing physical-device-only file-protection skip. UI: 125 passed, 24 failed out of 149. This run is explicitly not green.
- Exact checkpoint comparison: all 24 failed UI cases rerun against an isolated `git archive` of `8685249d`, separate build directory, same simulator/configuration. `/tmp/ff-ux-checkpoint-comparison26.xcresult`: 20 failures reproduced before this work, four passed. No current checkout files were reset or replaced.
- Final source regression run with actual system Increase Contrast and Reduce Motion enabled: `/tmp/ff-ux-final-actions26.xcresult`. All 866 unit/integration functions passed again, with the same one physical-only skip. The four differing UI cases passed: appointment service scheduling/start at largest text, native invoice menu/payment route, stop identity after relocation, and visit service replacement/clear-work confirmation. The initial broad run exposed two necessary corrections: restore combined stop name/date/time accessibility identity beside the separate directions action, and scroll toward the relocated Start Visit action in the existing UI helper. Invoice/menu and visit confirmation passed unchanged on rerun; retain their earlier failures as evidence of intermittent automation.
- Added stop identity/directions regression passed in `/tmp/ff-ux-stop-accessibility26.xcresult` at normal/light and largest-text/dark with system contrast/motion settings enabled. A first test assertion compared a native presented-sheet transformed AX frame directly against 44 points (reported 42.25); it was replaced by a semantic native action-role/label and hittability assertion. The shared view still specifies the existing 44-point minimum, and full-screen appointment tests assert that target size.
- Every new search/draft/service/payment/conflict workflow passed in the broad run. Focused runs also verified targeted replacement, Save Progress and relaunch, independent horse work, unconfirmed payment cancellation, all five protected creation drafts, and error/retry preservation.
- Compact iOS 18 (iPhone SE, third generation): all 866 unit/integration functions passed, same one physical-only skip, in `/tmp/ff-ux-final-compatibility18.xcresult`. All ten selected affected UI cases ultimately passed across `/tmp/ff-ux-final-compatibility18.xcresult`, `/tmp/ff-ux-final-workflows18.xcresult`, `/tmp/ff-ux-final-interactions18.xcresult`, and the successful `/tmp/ff-ux-draft-protection18-final.xcresult`. These cover seven new field-workflow checks, named conflict review, existing appointment service-to-visit flow at largest text, and stop relocation/editing. Earlier mixed results are retained: initial compact run had four UI failures; the next workflow run had two; the next interaction run had one. UI helpers were corrected to wait for actual keyboard focus, target vertical text input as either native TextField or TextView, keep scrolling above the keyboard, activate the native location menu at its visible control, and drag the sheet grabber instead of the status bar. The last issue was confirmed by a screenshot showing Notification Center above an intact client draft; no application dismissal or persistence fix was needed. A subsequent draft-only check also exposed the same native location-menu AX activation issue already diagnosed in stop editing; targeting the actual control resolved it. Both attempts to dismiss each of the five changed creation sheets now preserve input.
- Final iOS 26 recheck: `/tmp/ff-ux-final-interactions26.xcresult`, exit 0, all four selected native workflows passed: service creation/replacement and relaunch, protected drafts across all five forms, payment keyboard/draft/cancel, and stop location/horse editing. The final source builds and affected interactions pass on both runtimes. The broad 20 incumbent UI failures above remain unmodified and are not presented as green.
- System Reduce Motion and Increase Contrast were observed in native Settings, enabled for the final primary accessibility/action checks, and restored to their original Off/disabled values. Light appearance and large content-size defaults were verified restored. Auto-Play Message Effects remained at its original On value after Settings was relaunched. This demonstrates functional interaction under the settings; no video-based animation-quality claim is made.

The 20 incumbent UI failures remain visible, with no test skips or expected-failure annotations added. They include older Business/Clients back-navigation and offscreen-row assumptions, Today action expectations, onboarding centering/scroll assumptions, sync status pixel-position assumptions, historical Schedule row matching, and the old expectation that deleting an active appointment must be blocked. These need a dedicated test-maintenance review against the already checkpointed product behavior; no unrelated navigation, deletion or sync rewrite was introduced to satisfy them. Exact identifiers:

- `AppointmentSetupUITests/testInitialServicesDoNotBypassSubscription`
- `AppointmentSetupUITests/testInitialServiceSetupPersistsAndIsManagedFromMyBusiness`
- `AppointmentSetupUITests/testInitialServiceSetupSupportsLargestText`
- `BackupSyncUITests/testBackupSettingsHierarchyRemainsReadableInDarkModeAtAccessibilityXXXL`
- `BackupSyncUITests/testHistoryEntryPointsAtAccessibilityXXXLInDarkMode`
- `BackupSyncUITests/testOfflineRetryKeepsTheSyncActionInPlaceAtAccessibilityXXXL`
- `BackupSyncUITests/testOptionalBackupIsReadableAtAccessibilityXXXL`
- `BackupSyncUITests/testQueuedDeletionCanConfirmCompletionWithoutOfferingOrdinarySignIn`
- `BackupSyncUITests/testReadOnlyBusinessStillScrollsToDefaults`
- `BadgeAlignmentUITests/testInvoiceListStatusRemainsReadableAtAccessibilityTextSize`
- `BlockedMutationUITests/testHorseClientAndLocationEditThenDeleteWithoutInvalidatedRows`
- `BlockedMutationUITests/testReferencedRecordsAreBlockedUntilAppointmentIsDeleted`
- `OwnerSetupUITests/testBusinessIdentityGroupCentersBelowTheHero`
- `OwnerSetupUITests/testFirstCustomerFlowReachesInvoiceReadyAndPersists`
- `ServiceDeletionUITests/testLargestTextSheetDeletesServiceAndRecordedWork`
- `StopDetailsEditingUITests/testSharedEditorSavesAndCancelsWithoutLosingTabHistory`
- `SubscriptionReadOnlyUITests/testFullAccessKeepsExistingMutationControls`
- `TabSwitchingUITests/testTabSwitchesAtLargestTextInDarkMode`
- `TodayRunSheetUITests/testInvoiceActionIsImmediatelyReachableAtAccessibilityXXXL`
- `VisitCompletionUITests/testInProgressDiscardPreservesAppointmentAndBlocksAppointmentDeletion`

An initial focused build exposed actor isolation when reusing invoice-number formatting in conflict identity; the presentation helper and its tests now use the existing main-actor contract. Early UI checks also caught identifier inheritance in a native disclosure and a duplicate address label; both were corrected before the final checks.

An independent read-only review of the checkpoint-relative diff, new source/test files and audit found no concrete introduced correctness, data-loss, security or accessibility regression. This source assessment does not replace runtime verification. Final localization catalog dry-run passed; seven additive English source keys preserve all 876 existing entries. The latest light and largest-text dark appointment captures confirm Start Visit remains visible initially without changing the native navigation or grouped surfaces.

## Retained strengths and remaining opportunities

- Keep the current warm/light and charcoal/dark semantic palette, grouped surfaces, native Liquid Glass chrome, typography and restrained status colors. No new decorative icons, avatars, badges, custom cards or animations are needed.
- Keep direct Add Horse, independent per-horse appointment plans, optional scheduling services, exact recorded work and explicit persistence boundaries.
- Keep Pro read-only navigation and existing PDF access; optional backup remains independent of subscription entitlement.
- The single-eligible-service quick-add behavior is intentionally preserved. Reconsider it only with field evidence that the implicit choice causes errors.
- Larger catalogs/location directories and long archived invoice histories may benefit from additional native search later. No new global history destination or model is introduced here.
- Observe real farriers using the app outdoors, VoiceOver spoken traversal, physical-device phone/Maps handoff and purchase/sign-in lifecycle before claiming those experiences verified. These require hardware/services beyond simulator assertions.
- Profile a representative large real workspace before introducing caches or changing fetch architecture. No speculative caching, global reload mechanism or persistence rewrite is justified by this UI pass.


## Screenshot and diagnostic evidence

Inspected before/after captures include Today, Clients, Appointment Details, active Visit handling context, service selection, named sync conflicts and payment entry. Final representative captures:

- `/tmp/ff-ux-action26-captures/F8FAE7D7-DF5A-4FA0-BBA4-2F313F4034A4.png` — initially visible Start Visit, light.
- `/tmp/ff-ux-action26-captures/C6591958-74D3-46B7-BE60-24C25745DEEC.png` — initially visible Start Visit, largest text/dark.
- `/tmp/ff-ux-stop-accessibility26-captures/B4FFFE2E-C65B-4D34-AA55-D8DD9E81309D.png` and `3F6D54C9-FFE9-405E-98AD-44603E6E672D.png` — separate stop identity/directions, light and largest-text/dark with increased contrast.
- `/tmp/ff-ux-final-focused26-captures/5CCFF7F7-64DE-45EA-91EE-114BEFE603C9.png` — readable Record Payment title, persistent labels and native toolbar action.
- `/tmp/ff-ux-final-focused26-captures/582440D3-C4B4-4BB6-8C32-04330AD548E8.png` — active owner/handling notes, largest text/dark.
- `/tmp/ff-ux-accessibility-settings/` — actual system settings before, enabled and restored.

SwiftUI/UIKit toolbar-hosting and keyboard invalid-frame diagnostics also occur in passed pre-task artifacts `/tmp/ff-appointment-visible-plans26-accessibility-verified.xcresult` and `/tmp/ff-appointment-hierarchy26-release-check.xcresult`. No suppression or custom UIKit/keyboard workaround was introduced to hide them. There is no newly introduced Swift compiler diagnostic.


## Final state

Implementation and necessary validation are complete. The checkpoint remains HEAD; refinements are uncommitted and unstaged, and nothing was pushed. Final whitespace/diff, catalog-preservation/compile, changed-file and credential-pattern checks pass. Both task simulator destinations are shut down, original XcodeBuildMCP defaults restored, and task-started app/log/test processes cleaned up. No development server or watcher was started or retained. The 20 reproduced incumbent UI failures and the physical/live-service verification limits above remain explicit.
