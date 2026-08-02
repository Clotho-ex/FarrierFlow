# Slice 5A — Owner Setup and Today Run Sheet Plan

**Goal:** Make FarrierFlow owner-first: collect recurring business setup once, apply smart defaults only to new drafts, and turn Today into a deterministic field-work hub.

**Source of truth:** `docs/superpowers/specs/2026-08-02-slice-5a-owner-setup-field-book-design.md`.

## Implementation

1. Extend `BusinessProfile` with optional positive appointment-duration and invoice-due-day defaults; expose them in the existing profile editor and validate/persist them.
2. Gate a missing/invalid profile behind one required business-name field. Save identity, open Today immediately, and keep Services, Service Locations, contact information, and defaults in their contextual post-activation features.
3. Apply profile defaults once when creating new Appointment and Invoice drafts. Preserve manual edits, cleared due dates, existing records, and already-open drafts.
4. Replace Today’s appointment list with immutable summaries and deterministic ranking: active Visit, next current-day Appointment, first Client, uninvoiced work, unpaid Invoice, then scheduling. Recover missing Service Locations inside Appointment creation and missing Services inside Visit work recording. Exclude the promoted record from the following schedule list.
5. Render the promoted scheduled/active action as the approved Survey Ink Run Sheet band. Keep setup, billing, remaining appointments, loading, failure, and empty states flat and native.
6. Keep activation continuous: create a missing Client from the horse editor without losing draft state, show saved stop details before work, resume an active Visit in its editor, and return completed work to Today for invoice ranking.

## Focused Verification

- Unit: Business Profile rules/editor, Appointment defaults, Invoice defaults/date behavior, Today ranking/deduplication, nested Client selection, and Client invoice readiness.
- Persistence: Business Profile defaults survive a real container reopen.
- UI: one first-run-to-Today smoke and scheduled/active Run Sheet assertions if local resources permit.
- Build: one iOS 26 simulator build after focused tests.
- Hygiene: serial commands, one simulator, parallel testing disabled, `git diff --check`, final diff review.

No commit, push, PR, deploy, or release without separate approval.
