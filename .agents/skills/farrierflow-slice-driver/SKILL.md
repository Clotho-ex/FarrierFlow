---
name: farrierflow-slice-driver
description: Drive one explicitly approved FarrierFlow slice task or implementation unit through scoped implementation, focused verification, diff audit, manual verification, and commit. Use when Codex is asked to implement or continue one approved FarrierFlow unit while preserving local workflow state, serial resource-constrained testing, and explicit approval gates before push or the next unit.
---

# FarrierFlow Slice Driver

Read `docs/workflow/FARRIERSLICE_WORKFLOW.md` completely before acting. Follow
that procedure together with the repository-root `AGENTS.md`; higher-priority
instructions and the user's explicit scope continue to control.

## Start safely

1. Inspect the current branch and `git status --short` without inspecting any
   stash.
2. Read `.agents/workflow/CURRENT_UNIT.md`. If it does not exist, create the
   template defined in the workflow guide and stop in `no-approved-unit`. Never
   invent a unit.
3. If uncommitted changes exist, use the approved and excluded scope in
   `CURRENT_UNIT.md` to classify every changed path before taking any other
   action. If any path is unrelated or ambiguous, record `blocked` and stop
   without changing the worktree.
4. Read `AGENTS.md`, the active Slice specification, and its implementation
   plan. Confirm that the unit, branch, and permitted changes are explicit and
   consistent. Otherwise remain in `no-approved-unit` or enter `blocked`.

## Drive one unit

- Use only the state machine and gates in the workflow guide. Keep
  `CURRENT_UNIT.md` current after every completed or failed gate, but never
  stage it.
- Implement only the approved unit. Do not add speculative abstractions,
  unrelated refactors, deferred scaffolding, or schema changes not explicitly
  required by that unit.
- Run only the recorded focused, serial verification while developing. Reserve
  complete suites for an explicitly approved final-integration gate.
- On a failed gate, stay in the same unit, apply only a concrete in-scope fix,
  and repeat the failed gate. Stop early only when genuinely blocked.
- Audit the complete diff, rerun focused verification after fixes, and perform
  simulator or manual verification for user-facing flow changes.
- Commit only after every required gate passes. Audit the staged diff, use a
  narrow imperative message, record the SHA, transition to
  `committed-awaiting-push`, and stop.

Never inspect, apply, drop, or modify a stash. Never reset or discard
uncommitted work. Never push, open a pull request, merge, or start another unit
without explicit user approval. Report exact command results and blockers; do
not convert failed verification into a success claim.
