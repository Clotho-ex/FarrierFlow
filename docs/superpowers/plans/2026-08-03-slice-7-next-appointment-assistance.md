# Slice 7 — Next Appointment Assistance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `superpowers:test-driven-development` for each behavior change and
> `superpowers:verification-before-completion` before reporting the slice
> complete. Steps use checkbox syntax to define each unit's required gates;
> the execution-status lines record the live implementation state.

**Goal:** Help a farrier turn one completed Visit into one reviewed, ordinary
future Appointment without automatic creation, persisted follow-up state, or
duplicate scheduling for individual Horses.

**Architecture:** Keep Schedule responsible for actor-neutral suggestion rules,
a transient `@MainActor @Observable` SwiftData projection, the assistant UI,
and an immutable seed. Visits emits only a successfully persisted Visit
identifier. `AppointmentEditorModel` remains the sole validation and save
boundary. Every opening projects current graph truth; no new model, migration,
repository, source-Visit link, or follow-up flag is introduced.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, Observation, SwiftData,
Foundation Calendar, Swift Testing/XCTest, iOS 18.0 minimum, latest stable iOS
26 SDK.

**Execution status (2026-08-04):** Units 1 through 5 are complete. Unit 6 has
not started. No final Slice 7 acceptance or completion claim has been made.

## Global Constraints

- Implement only
  `docs/superpowers/specs/2026-08-03-slice-7-next-appointment-assistance-design.md`
  after Slice 7 and the first implementation unit are explicitly authorized in
  `.agents/workflow/CURRENT_UNIT.md`.
- Preserve all exclusions: no schema migration, persisted follow-up state,
  repository layer, automatic or recurring Appointment, reminders,
  notifications, Today ranking changes, new tab/dashboard, customer-facing
  flow, payments, export, subscriptions, backup, or unrelated UX work.
- Do not modify `FarrierFlowSchemaV1`, `CurrentSchema`,
  `FarrierFlowMigrationPlan`, or any `Core/Persistence/Schema` file.
- Pass `PersistentIdentifier` values across routes. Keep SwiftData access in
  main-actor feature models; keep Calendar and ordering rules actor-neutral.
- One projection receives one caller-captured `now`. No projection helper or
  assistant view reads `.now` again. Retry/reopen may capture a new instant.
- Use native `NavigationStack`, `Form` or `List`, `Section`, `DatePicker`,
  `sheet`, `ContentUnavailableView`, buttons, and accessibility modifiers. Add
  no custom controls, cards, gradients, or navigation.
- New source files are discovered by the existing synchronized Xcode groups;
  do not edit `project.pbxproj` unless the build proves discovery is broken.
- Run build/test commands serially. Before each, separately run:

  ```bash
  pgrep -fl 'xcodebuild|xctest|XCTRunner'
  memory_pressure
  sysctl vm.swapusage
  ```

  Stop if a runner survives, memory pressure is elevated, or swap is rising.
  Never overlap `xcodebuild` processes or create simulator clones.
- Reuse the verified simulator destinations, resolving them again only if they
  no longer exist:

  ```bash
  IOS18_DESTINATION='platform=iOS Simulator,id=02DB4E38-DF46-4F30-A8C8-C4D4DF46FDA4'
  IOS26_DESTINATION='platform=iOS Simulator,id=A9501C1D-4747-4310-8F2B-F0587E0E30C6'
  ```

- Before every unit commit: run `git diff --check`; stage only that unit's
  listed files; inspect `git diff --cached --check` and `git diff --cached`;
  then commit. Never stage `.agents/workflow/CURRENT_UNIT.md`.

## Resolved Contract

1. **Invalid source Appointment is a projection failure.** The completed Visit
   must have `completedAt >= startedAt`; Visit and Appointment must resolve one
   another; both must resolve the same valid Service Location; and unique,
   inverse-valid AppointmentHorse and VisitHorse memberships must contain the
   same Horse IDs. Failure yields `failed(.sourceAppointmentUnavailable)` with
   Retry and Done. No partial projection, snapshot substitution, invented time,
   or unseeded editor is allowed.
2. **Newer serviced Visit uses one total order.** Exclude the source Visit ID.
   For the same Horse, consider only completed, inverse-valid `.serviced`
   candidates. A candidate supersedes the source exactly when it sorts before
   it by `startedAt` descending, `completedAt` descending, then Visit persistent
   ID ascending. Equal timestamps therefore use the lower ID as deterministic
   precedence, not as inferred chronology.
3. **Projection time is stable.** The same injected `now` controls future
   Appointment detection (`startDate >= now`), past suggestions
   (`suggestedStart < now`), next-half-hour fallback, and selection-driven group
   proposals. Selection edits retain it; retry/reopen begins a new projection.
4. **Partial-save reopening is per Horse.** Exclude the source Appointment from
   duplicate detection. Horses in any saved future Appointment are disabled and
   show Already Scheduled. Remaining eligible Serviced Horses are preselected;
   eligible Not Serviced Horses remain unselected and selectable. Recompute the
   group proposal from remaining selected suggestions. Never merge into the
   saved Appointment. Editing/removing that membership, deletion, or passage
   out of the future threshold restores eligibility on a fresh projection.

---

## Unit 1 — Actor-Neutral Suggestion and Recency Rules

**Goal:** Establish the temporal and ordering contract before SwiftData or UI
work.

**Execution status:** Committed as `4d33c8b`.

**Files likely affected**

- Create `FarrierFlow/Features/Schedule/NextAppointmentSuggestionRules.swift`.
- Create
  `FarrierFlowTests/Features/Schedule/NextAppointmentSuggestionRulesTests.swift`.

**Domain invariants**

- `CompletedVisitRecency` contains Visit ID, `startedAt`, and valid
  `completedAt`; it owns no model reference.
- `precedes(_:_:sourceVisitID:)` rejects the source ID before applying the
  three-level total order.
- Suggested dates use Calendar week arithmetic from `Visit.startedAt`'s local
  day and apply the source Appointment's local hour/minute. Never add fixed
  seconds.
- Nonpositive intervals produce no suggestion.
- `groupSuggestedStart(selectedSuggestedDates:)` returns the earliest selected
  suggestion without hiding a historical date. `editorStart(groupSuggestion:
  now:calendar:)` returns that value when it is at or after `now`, otherwise it
  uses `AppointmentStartDateRules.nextHalfHour(after:calendar:)`.
- A suggestion exactly equal to `now` is not past.

**Focused tests**

- [ ] Add failing tests for normal week addition and source hour/minute.
- [ ] Add spring-forward and fall-back DST tests using an explicit Gregorian
  Calendar and fixed time zone.
- [ ] Add tests for earliest of multiple intervals, no selected suggestion,
  exact-`now`, and past fallback.
- [ ] Add tests proving source exclusion, started-time ordering,
  completion-time ordering, and equal-timestamp ID ordering.
- [ ] Implement only the value type and rule functions required by those tests.
- [ ] Run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/NextAppointmentSuggestionRulesTests
  ```

  Expected: the new suite passes; no SwiftData or UI source changes.

**Manual verification:** None. This unit has no visible surface; deterministic
unit tests are its complete verification.

**Commit boundary:** Stage only the two listed files and commit
`feat(schedule): add next appointment suggestion rules`.

**Model and effort recommendation:** `gpt-5.6-sol`, high.

---

## Unit 2 — Current-Graph Assistant Projection

**Goal:** Project every source Visit Horse into a truthful transient state using
current SwiftData records and the resolved contract.

**Execution status:** Committed as `02c994d`.

**Files likely affected**

- Create
  `FarrierFlow/Features/Schedule/Models/NextAppointmentAssistantState.swift`.
- Create `FarrierFlow/Features/Schedule/Models/NextAppointmentSeed.swift`.
- Create `FarrierFlow/Features/Schedule/NextAppointmentAssistantModel.swift`.
- Create
  `FarrierFlowTests/Features/Schedule/NextAppointmentAssistantModelTests.swift`.
- Modify `FarrierFlowTests/Support/ModelFixtures.swift` only if a reusable
  completed multi-Horse fixture removes duplication.

**Planned interface**

```swift
nonisolated struct NextAppointmentSeed: Equatable {
    let barnID: PersistentIdentifier
    let horseIDs: Set<PersistentIdentifier>
    let startDate: Date
    let hasFollowUpSuggestion: Bool
}

@MainActor @Observable
final class NextAppointmentAssistantModel {
    func load(
        in context: ModelContext,
        now: Date,
        calendar: Calendar,
        locale: Locale
    )
    func toggleHorse(_ visitHorseID: PersistentIdentifier)
    func setProposedStart(_ date: Date)
    func makeSeed() -> NextAppointmentSeed?
}
```

The state file should contain small Equatable values for load state, load error,
Horse option, unavailability reason, and projection summary. Do not expose live
SwiftData models to the view.

**Domain invariants**

- Validate the source Visit/Appointment graph before producing any Horse row.
  Invalid source state fails globally as `.sourceAppointmentUnavailable`.
- A malformed Horse-specific graph fails closed only for that Horse after the
  source graph passes.
- Query current AppointmentHorse and VisitHorse truth directly through
  `ModelContext`; add no repository or persisted result.
- Exclude the source Appointment from future-Appointment detection and the
  source Visit from supersession detection.
- Evaluate future Appointment first for duplicate protection, then newer work,
  moved location, Client, interval, and outcome validity; publish one factual
  reason per unavailable Horse.
- Eligible Serviced Horses start selected with suggestions. Eligible Not
  Serviced Horses start unselected without suggestions.
- Store the injected `now` in projection state. Selection changes reuse it.
  `setProposedStart` marks the projection manually overridden permanently, so
  later selection changes cannot replace the chosen date.
- `makeSeed()` returns nil when nothing is selected or the projection failed.
  Calling it never writes to the context.

**Focused tests**

- [ ] First write tests for missing Appointment, broken inverse, location
  mismatch, completion before start, duplicate membership, and unequal Horse
  membership; each must fail the whole projection.
- [ ] Add per-Horse tests for Serviced, Not Serviced, missing Client, invalid
  interval, moved Horse, future Appointment, newer serviced Visit, and corrupt
  candidate history.
- [ ] Prove mixed-client Horses at one Service Location remain independently
  selectable.
- [ ] Prove the source Visit cannot supersede itself and equal timestamps use
  the persistent-ID tie-break; prove the source Appointment does not count as a
  future duplicate even if its start is at or after `now`.
- [ ] Prove one stable `now` is used on both sides of the future and past
  thresholds, including selection changes after load.
- [ ] Prove partial-save reopening disables only scheduled Horses, reselects
  the remaining eligible Serviced Horses, leaves Not Serviced unselected, and
  recalculates from the remaining suggestions.
- [ ] Prove removing a future membership or deleting the Appointment restores
  eligibility after a fresh load.
- [ ] Implement the smallest projection that passes the tests, then run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/NextAppointmentAssistantModelTests
  ```

  Expected: all projection states and stable-time cases pass; the persistent
  model schema remains untouched.

**Manual verification:** None. This is a headless projection unit; its in-memory
SwiftData tests are the verification boundary.

**Commit boundary:** Stage only the state, seed, model, focused test, and any
exact fixture addition. Commit
`feat(schedule): project next appointment eligibility`.

**Model and effort recommendation:** `gpt-5.6-sol`, high.

---

## Unit 3 — Seed the Existing Appointment Editor

**Goal:** Prefill the ordinary Appointment draft without bypassing its current
validation, owner defaults, editability, or save transaction.

**Execution status:** Committed as `ce2778d`.

**Files likely affected**

- Modify `FarrierFlow/Features/Schedule/AppointmentEditorModel.swift`.
- Modify `FarrierFlow/Features/Schedule/Views/AppointmentEditorView.swift`.
- Modify
  `FarrierFlowTests/Features/Schedule/AppointmentEditorModelTests.swift`.
- Modify `FarrierFlow/Resources/Localizable.xcstrings` only for seed guidance
  visible in the editor.

**Planned interface:** Add optional `NextAppointmentSeed` input to the
new-Appointment model/view initializer and an
optional `onSaved: (PersistentIdentifier) -> Void` view callback. Preserve all
existing call sites with defaults. Existing Appointment editing ignores a seed.

**Domain invariants**

- Seed only Service Location, selected Horses, start date, and whether the date
  came from a Horse suggestion. Never copy notes, work, services, prices,
  photographs, Invoice, or payment data.
- Apply the existing owner duration default exactly once, as ordinary new
  Appointment creation does.
- `load(in:)` revalidates the seeded Service Location and prunes Horses no
  longer eligible there. It preserves the rest of the draft and surfaces the
  existing save requirement.
- Every seeded value remains visible and editable. Save still calls only
  `AppointmentEditorModel.save(in:)` and creates one ordinary Appointment.
- Cancel creates nothing. Save failure keeps the draft and shows the existing
  recoverable alert.

**Focused tests**

- [ ] Write failing tests for applying Barn/Horses/start seed and leaving notes
  empty.
- [ ] Prove the owner duration default still applies once and user edits
  survive reload.
- [ ] Prove existing Appointment editing ignores a supplied seed.
- [ ] Prove moved/deleted seeded Horses are pruned at load and cannot bypass
  save validation.
- [ ] Prove the existing save boundary returns the created Appointment ID and
  failed save preserves the draft; Unit 5's focused UI flow verifies the view
  callback is emitted only for that successful ID.
- [ ] Implement and run:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/AppointmentEditorModelTests
  ```

  Expected: seeded and ordinary editor tests pass without a second save path.

**Manual verification:** From a temporary preview/debug fixture, open one
seeded editor and confirm Service Location, Horses, start, and duration are
editable; cancel and confirm no Appointment appears. Do not add a permanent
debug screen.

**Commit boundary:** Stage only the editor model/view, focused tests, and exact
catalog entries. Commit `feat(schedule): seed follow-up appointment drafts`.

**Model and effort recommendation:** `gpt-5.6-sol`, high.

---

## Unit 4 — Native Assistant and Visit-Detail Recovery

**Goal:** Present the projection as a flat, field-ready assistant and make it
recoverable from a completed Visit without adding navigation or persisted task
state.

**Execution status:** Committed as `8195830`.

**Files likely affected**

- Create
  `FarrierFlow/Features/Schedule/Views/NextAppointmentAssistantView.swift`.
- Modify `FarrierFlow/Features/Visits/Views/VisitDetailView.swift`.
- Modify `FarrierFlow/Resources/Localizable.xcstrings`.
- Extend
  `FarrierFlowTests/Features/Schedule/NextAppointmentAssistantModelTests.swift`
  only for interaction state not already covered.

**Domain invariants**

- Capture one `let projectionNow = Date.now` immediately before each load/retry
  and pass it once with the environment Calendar and Locale.
- Use native Form/List rows. Each Horse exposes name, Visit outcome, interval,
  suggestion, selection, or one unavailable reason without relying on color.
- Not Now and Done dismiss without writes. Continue is disabled until at least
  one selectable Horse is selected.
- DatePicker edits call `setProposedStart`; after that, Horse selection never
  overwrites the manual date.
- Present `AppointmentEditorView(seed:)` from the assistant. Editor Cancel
  returns to the same transient assistant state. Save routes to the existing
  Appointment detail within the assistant NavigationStack.
- Completed Visit Detail uses the Schedule-owned projection to show Schedule
  Next Appointment while any Horse is selectable; otherwise it shows current
  Already Scheduled, moved, superseded, or unavailable truth. Every opening
  reloads; no dismissed state is restored.
- No Today ranking or Horse History navigation changes.

**Focused tests**

- [ ] Add/confirm model tests for selection-driven recalculation, permanent
  manual override, disabled Continue state, and Calendar-failure fallback.
- [ ] Implement the assistant's loading, loaded, and failed native states.
- [ ] Add Visit Detail recovery section and presentation using a Visit ID.
- [ ] Run the Schedule model suites and Visit detail model suite:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/NextAppointmentAssistantModelTests \
    -only-testing:FarrierFlowTests/VisitDetailModelTests
  ```

  Expected: interaction state and existing Visit detail behavior pass.

**Manual verification:** On iOS 26, inspect one three-Horse fixture in Light and
Dark Mode at default and accessibility Dynamic Type. Verify VoiceOver announces
name, outcome, interval, suggestion, then selection/reason; test Increased
Contrast, Not Now, editor Cancel, and partial-saved reopening from Horse History.

**Commit boundary:** Stage only the assistant view, Visit detail view, focused
test additions, and exact localization entries. Commit
`feat(schedule): add next appointment assistant`.

**Model and effort recommendation:** `gpt-5.6-sol`, high.

---

## Unit 5 — Post-Completion Handoff

**Goal:** Open the assistant only after successful Visit completion, from both
Today and Appointment Detail, with safe sheet sequencing.

**Execution status:** Complete. The focused UI suite and both required
post-completion simulator flows passed.

**Files likely affected**

- Modify `FarrierFlow/Features/Visits/Views/VisitEditorView.swift`.
- Modify `FarrierFlow/Features/Today/Views/TodayView.swift`.
- Modify
  `FarrierFlow/Features/Schedule/Views/AppointmentDetailView.swift`.
- Modify `FarrierFlowUITests/VisitCompletionUITests.swift` for focused handoff
  coverage only.

**Planned interface**

Change `VisitEditorView.onCompleted` to
`((PersistentIdentifier) -> Void)?`. Call it with the source Visit ID only after
`completeVisit()` returns success. Preserve the current correction flow.

**Domain invariants**

- Failed or rejected completion never emits an ID and never presents the
  assistant.
- The Visit editor dismisses fully before either presenter opens the next sheet.
  Use pending Visit-ID state consumed from the existing sheet `onDismiss`; do
  not stack simultaneous sheets or add a global coordinator.
- Today adds only a transient assistant sheet case. Its model, primary-action
  ranking, chronological content, and reload rules do not change.
- Appointment Detail defers its existing completion callback until the
  assistant finishes, so the farrier sees the offer before returning to Today.
- Not Now creates no Appointment. Closing the assistant reloads the presenting
  surface normally.

**Focused tests**

- [ ] Update compile-time call sites for the ID-bearing callback.
- [ ] Add UI coverage proving successful completion dismisses Visit then shows
  Next Appointment.
- [ ] Add a failure-path assertion that an incomplete/invalid Visit cannot show
  the assistant.
- [ ] Add Not Now coverage proving no Appointment is created.
- [ ] Run only the focused flow:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests/VisitCompletionUITests
  ```

  Expected: handoff occurs once, only after successful persistence, and Not Now
  leaves Schedule unchanged.

**Manual verification:** Complete a Visit once from Today and once from
Appointment Detail. Confirm the Visit sheet disappears before Next Appointment,
there is no flash of a second Visit editor, Not Now returns cleanly, and Today
still prioritizes its existing Invoice action afterward.

**Commit boundary:** Stage only the three views and focused UI-test changes.
Commit `feat(visits): offer next appointment after completion`.

**Model and effort recommendation:** `gpt-5.6-sol`, high.

---

## Unit 6 — Acceptance, Relaunch, and Slice Closure

**Goal:** Prove the complete three-Horse flow, subset-save reopening, ordinary
Appointment persistence, accessibility, and platform compatibility without
adding product behavior.

**Execution status:** Not started.

**Files likely affected**

- Add `nextAppointment` to
  `FarrierFlow/App/UITestLaunchConfiguration.swift`.
- Modify `FarrierFlow/Core/Persistence/PreviewFixtures.swift` with one completed
  Visit containing two Serviced Horses with different intervals and one Not
  Serviced Horse.
- Create `FarrierFlowUITests/NextAppointmentFlowUITests.swift`.
- Modify
  `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift` with the
  saved-subset reopen case.
- Modify `ROADMAP.md` only after all final gates pass, marking Slice 7 complete
  with its actual behavior and retaining every deferral.
- Modify
  `docs/superpowers/specs/2026-08-03-slice-7-next-appointment-assistance-design.md`
  only if implementation evidence requires a non-behavioral clarification.

**Domain invariants**

- UI fixtures use only the existing schema and ordinary records.
- The acceptance flow creates exactly one Appointment with the selected subset
  and survives store reopening.
- On fresh projection, only Horses in a future Appointment are Already
  Scheduled; unsaved source Horses remain independently actionable.
- Dismissal before Save leaves no record. No migration or follow-up state is
  introduced.

**Focused tests and manual verification**

- [ ] Automate: two Serviced selected with individual suggestions; Not Serviced
  unselected without suggestion; earliest group date; Not Now no record;
  recovery through Horse History; deselection recalculation; manual override;
  save; Appointment detail; partial duplicate state.
- [ ] Add persistent-store reopen coverage for the saved subset and fresh
  duplicate projection.
- [ ] Manually repeat the acceptance flow on iOS 26 with VoiceOver and
  accessibility Dynamic Type, then smoke-test the same flow on iOS 18.
- [ ] Run the final gates once, serially, with the resource preflight before
  every command:

  ```bash
  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests \
    -skip-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests \
    -skip-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests/NextAppointmentFlowUITests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowUITests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild test -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION" \
    -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 \
    -only-testing:FarrierFlowTests/PersistentStoreReopenTests

  xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS18_DESTINATION"

  xcodebuild build -project FarrierFlow.xcodeproj -scheme FarrierFlow \
    -destination "$IOS26_DESTINATION"

  plutil -lint FarrierFlow/Resources/Localizable.xcstrings
  git diff --check
  ```

  Expected: both unit suites, focused iOS 18 flow, full iOS 26 UI suite,
  reopening gates, builds, catalog lint, and diff check pass. There is no
  migration gate because no schema change exists.

**Commit boundary:** After all gates pass, stage only the fixture, launch
scenario, acceptance/reopen tests, and truthful roadmap/spec updates. Commit
`test(schedule): verify next appointment assistance`.

**Model and effort recommendation:** `gpt-5.6-sol`, high.

## Execution Handoff

Unit 5 is complete. Do not begin **Unit 6 — Acceptance, Relaunch, and Slice
Closure** without explicit user approval.
