# FarrierFlow Slice Workflow

This workflow drives one explicitly approved implementation unit from clean
scope confirmation through a local commit. It does not authorize a second unit,
a push, a pull request, or a merge.

## Sources of authority

Use these sources in descending order:

1. Current user instructions.
2. Repository-root `AGENTS.md` and any more-specific agent instructions.
3. The approved Slice specification.
4. The approved Slice implementation plan.
5. `.agents/workflow/CURRENT_UNIT.md`.

The unit ledger records approval; it cannot broaden the specification or plan.
If these sources conflict in a way that affects implementation, enter
`blocked`, preserve all work, and report the contradiction.

## Non-negotiable boundaries

- Drive exactly one approved unit at a time.
- Never inspect, apply, drop, clear, or modify a stash.
- Never reset, discard, overwrite, or reformat uncommitted work.
- Never push, open a pull request, merge, or begin another unit without
  explicit user approval.
- Do not change a schema unless the approved unit explicitly requires it.
- Do not add speculative abstractions, future-unit scaffolding, dependencies,
  or unrelated refactors.
- Do not run a complete suite before the explicitly approved final-integration
  gate.
- Do not hide failed, blocked, skipped, or incomplete verification.
- Do not claim success without the exact command result that supports it.
- Do not repeat product questions when the approved specification provides one
  safe, in-scope implementation.
- Keep `CURRENT_UNIT.md` local and untracked. Never stage or commit it.

## State machine

Use exactly one of these states in `CURRENT_UNIT.md`:

| State | Meaning | Exit gate |
| --- | --- | --- |
| `no-approved-unit` | No explicit unit is recorded. | User approves one unit and its scope. |
| `implementation` | The approved unit is being implemented. | The scoped implementation and focused tests are ready to run. |
| `focused-verification` | Recorded focused checks are running serially. | Every required focused check passes with exact results recorded. |
| `diff-audit` | The complete tracked and untracked diff is under review. | No concrete in-scope finding remains. |
| `audit-fixes` | Concrete audit findings are being corrected. | Fixes are complete; repeat focused verification, then the diff audit. |
| `manual-verification` | A changed user-facing flow is being exercised. | Required simulator or manual checks pass, or are explicitly not required. |
| `ready-to-commit` | All implementation, verification, audit, and manual gates pass. | The staged diff is scoped and the commit succeeds. |
| `committed-awaiting-push` | The approved unit is committed locally. | User explicitly authorizes a push. |
| `pushed-awaiting-next-unit` | The approved commit was pushed with authorization. | User explicitly approves the next unit. |
| `blocked` | A concrete condition prevents safe progress inside the approved unit. | The blocker is resolved or the user supplies the required decision. |

Normal implementation transitions are:

`implementation` → `focused-verification` → `diff-audit` →
`manual-verification` → `ready-to-commit` → `committed-awaiting-push`.

A diff finding transitions `diff-audit` → `audit-fixes` →
`focused-verification`. A failed verification remains within the same unit:
record the failure, make only the smallest concrete in-scope correction, repeat
that gate, and continue. Use `blocked` only when work cannot safely continue,
not for ordinary red-green iteration or intermediate progress.

## Invocation procedure

### 1. Establish local state

1. Run `git branch --show-current` and `git status --short`.
2. Do not run any stash command.
3. Read `CURRENT_UNIT.md`. If absent, create the template at the end of this
   document, leave it in `no-approved-unit`, and stop.
4. If the worktree is not clean, classify every modified, deleted, renamed, and
   untracked path against the ledger's approved scope. Only the minimum
   read-only inspection needed for that classification may precede it.
5. If any path is outside the approved scope, overlaps ambiguously with it, or
   cannot be explained, set `blocked` and stop without modifying files.
6. Confirm the recorded branch matches the current branch. A mismatch blocks
   work unless the user explicitly authorized it.

### 2. Confirm approval and context

Read `AGENTS.md`, the active Slice specification, and the active implementation
plan completely. Derive the active documents from the explicitly named Slice
and task; if more than one document could apply, do not guess.

Confirm all of the following before entering `implementation`:

- The unit name and approved scope are explicit.
- The excluded scope is explicit enough to prevent adjacent-unit work.
- The current branch is approved.
- Focused test commands are recorded and comply with repository simulator,
  serial-testing, and memory constraints.
- Required manual verification is recorded, or explicitly says it is not
  required because no user-facing flow changes.
- The specification, plan, and unit ledger do not contradict one another.

If approval is missing, use `no-approved-unit` and stop. If approval exists but
a concrete inconsistency prevents safe work, use `blocked` and state the one
decision required.

### 3. Implement the unit

- Inspect existing implementations and tests before editing.
- Keep persistence, validation, formatting, navigation, and state ownership in
  the repository's established layers.
- Preserve unrelated work and existing behavior outside the approved change.
- Add only focused coverage required to demonstrate the changed behavior and
  prevent its material regressions.
- Update the implementation findings with decisions or constraints discovered
  during work. Do not use the ledger as a progress diary.
- Stay within `implementation` until the scoped code and focused tests are
  ready for verification.

### 4. Run focused verification

Before each Xcode command, follow the resource-stop policy in `AGENTS.md`:
inspect existing `xcodebuild`, `xctest`, and simulator test-runner processes;
do not overlap commands; and do not start when memory pressure or increasing
swap makes the run unsafe.

Run only the focused commands recorded in `CURRENT_UNIT.md`. Xcode tests must
use one destination, disabled parallel testing, and one test worker. Verify the
reported executed test count, not merely the command exit code. Do not run the
complete suite unless this unit is the approved final-integration gate.

Always run:

```bash
git diff --check
```

When `FarrierFlow/Resources/Localizable.xcstrings` changes, validate it with
the repository's established string-catalog command. If no project command is
documented, create a unique temporary directory with `mktemp -d` and run
`xcrun xcstringstool compile --dry-run --output-directory` using that directory
and the catalog path. Record the exact command, exit status, and output summary.

For every check, record:

- Exact command.
- Exit result.
- Executed test count and failures, when applicable.
- Environment or simulator used.
- Any warning that affects confidence.

On failure, keep the unit active, correct only a demonstrated in-scope cause,
and rerun the failed check. If the cause is out of scope or environmental and
cannot be safely cleared, enter `blocked` with the evidence.

### 5. Audit the complete diff

Review tracked and untracked paths, then inspect the full diff. Confirm:

- Every path and hunk belongs to the approved unit.
- The implementation matches the specification and plan without redesign.
- Data ownership, validation, persistence, and failure behavior are correct.
- No data-loss, crash, concurrency, accessibility, or backward-behavior risk is
  left unaddressed.
- No dead code, debug code, test-only production behavior, duplicated rules,
  or unsafe assumption was introduced.
- No deferred scaffolding, schema change, dependency, generalized framework,
  unrelated refactor, or formatting churn was added.
- User-visible text follows the localization convention.
- Focused coverage tests behavior and failure paths proportionately; important
  regression coverage is not missing.
- Generated artifacts, simulator output, temporary files, credentials, and
  local workflow state are absent from the diff.

Record findings by severity. For each concrete in-scope finding, enter
`audit-fixes`, apply the smallest correction, rerun focused verification, and
repeat the complete diff audit. An empty audit means no material finding was
found; it does not replace verification.

### 6. Perform manual verification

For a changed user-facing flow, exercise the exact path recorded in
`CURRENT_UNIT.md` on the required simulator or device. Verify success,
cancellation, error handling, persistence after relaunch when relevant,
accessibility behavior required by the unit, and absence of relevant runtime
errors. Capture the expected behavior, actual behavior, and result for every
step.

Do not add test-only production hooks merely to make a manual failure reachable.
If a required path cannot be exercised safely, record why and enter `blocked`
unless the approved gate explicitly permits focused automated evidence instead.
Dismiss presented UI and terminate app or simulator processes hygienically when
the verification instructions require cleanup.

If the unit has no user-facing flow change, record `Not required: no
user-facing flow changed` and advance without launching a simulator.

### 7. Commit and stop

Enter `ready-to-commit` only when all required checks pass, the final diff audit
has no unresolved findings, manual verification passes or is explicitly not
required, and `git diff --check` passes after the last edit.

Before committing:

1. Stage only the approved paths; never stage `CURRENT_UNIT.md`.
2. Inspect `git diff --cached --stat`, `git diff --cached --name-status`, and the
   complete `git diff --cached`.
3. Confirm the staged diff contains one cohesive unit and no unrelated or local
   files.
4. Use a narrow, imperative commit message describing the completed behavior.
5. Commit, record `git rev-parse HEAD`, and run `git status --short`.

Set the state to `committed-awaiting-push`, record the commit SHA and pushed
status as `not pushed`, then stop and request explicit approval to push. Do not
open a pull request, merge, or begin another unit as part of that approval.

After an explicitly authorized push, record the exact push result, set pushed
status to `pushed`, transition to `pushed-awaiting-next-unit`, and stop until the
user explicitly approves another unit.

## Reporting formats

### Gate completion

- **State:** exact state.
- **Gate:** check just completed.
- **Result:** exact command result and test count where applicable.
- **Findings:** concrete findings or `None`.
- **Next action:** next gate inside the same approved unit.

Do not stop merely to send this report unless the user asks for status or the
work is genuinely blocked.

### Blocked

- **State:** `blocked`.
- **Blocking condition:** concrete cause.
- **Evidence:** exact command result, path, runtime observation, or source
  contradiction.
- **Work preserved:** current changes and last passing gate.
- **Required decision:** smallest user decision or external change needed.

### Committed awaiting push

- **State:** `committed-awaiting-push`.
- **Commit:** SHA and message.
- **Files:** committed paths.
- **Verification:** exact focused test count/results, catalog validation when
  applicable, manual result, and `git diff --check` result.
- **Status:** exact `git status --short` output.
- **Required decision:** explicit approval to push, or no action.

## `CURRENT_UNIT.md` template

When the file is missing, create exactly this neutral state and stop. Do not
replace any `Not approved` or `None` value by inference.

```markdown
# Current FarrierFlow Unit

- Slice: Not approved
- Task: Not approved
- Unit name: Not approved
- Branch: Not approved
- Approved scope: None
- Excluded scope: None
- Focused test commands: None
- Required manual verification: None
- Current state: no-approved-unit
- Implementation findings: None
- Audit findings: None
- Verification results: None
- Commit SHA: None
- Pushed status: not pushed
- Next required user decision: Approve one implementation unit and its scope.
```
