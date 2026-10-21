# User-controlled deletion

Approved by the user on 2026-10-19; supersedes previous permanent-history deletion restrictions.

- A native content-sized confirmation states the actual operational records and photographs removed. Cancel and interactive dismissal never mutate data.
- Client deletion removes its horses and their memberships/work/photos. Horse deletion removes that horse's appointment and visit memberships, preserving other horses in shared appointments and visits. Empty appointments/visits are removed.
- Service deletion removes its catalog entry, clears horse defaults/planned choices, and removes matching recorded work. Other services and horses remain. A horse left without recorded work becomes Not Serviced, including in completed visits.
- Appointment and Visit deletion removes their dependent visit/work/photo records without manual prerequisite cleanup. Removing visit history also removes its source appointment so it does not reappear as unfinished work.
- Invoices remain independent snapshots with unchanged amounts, names, dates, payment evidence, identities and numbering. Source/client links may detach when those operational records are deleted. Invoice deletion is separately available for both paid and unpaid invoices, with payment-removal warning; it never deletes operational work.
- Financial values cannot be changed by detachment. Live links still require correct inverses, ownership and currency. Sync preserves owner/workspace authorization, conflict checks, atomic dependency batches and tombstones.
- Completed Visit corrections allow every horse to be Not Serviced and show validation guidance rather than silently disabling Save. Invoiced work corrections preserve the independent invoice snapshots and prevent accidental repeat billing.
- Photographs use the existing coordinated quarantine/rollback path. Database failure leaves all original records/files usable.
- Recalculate deletion effects immediately before commit; changed dependencies require a new confirmation.
- Test on isolated data only. Do not erase the user's current RESTORE TEST or other business records during development.

Implementation uses the existing V5 optional source links; no persisted property
or schema version is changed. Protocol 3 is required before detached snapshots
can be pulled by another client. Pending version 1/2 operations retain their
original protocol and payload for idempotent replay. The incremental update is
`supabase/updates/user_controlled_deletion.sql`; it rewrites no business records.

Validation so far: 240 focused iOS 26.5 cases passed, including source/snapshot
round trips, rollback, persistent reopening, migration and photo quarantine.
The canonical schema and old-schema-plus-update produce identical PostgreSQL
catalogs. Existing sync, invoice history, appointment-service and bounds SQL
contracts pass; new deletion/hold/paid snapshot checks pass on both fresh and
upgraded databases. Local SQL uses isolated PostgreSQL 17.11 with test-only Auth,
Storage and Realtime scaffolding; this does not prove hosted HTTP or broadcasts.
Hosted baseline function hashes match the reviewed pre-update source. The user approved deployment. Migration `20261019203913_user_controlled_deletion`
is installed in FarrierFlow Dev; all ten deployed function hashes match the
reviewed update. The hosted synthetic rollback contract passed, and independent
readback confirmed zero remaining synthetic users/workspaces. The update did not
rewrite business records.

Native iOS 26.5 deletion/cancellation/swipe/largest-text tests passed after fixing
two test assumptions: relaunch must not reseed a deleted fixture, and deleting one
of two visits must keep the other visit. The refined run passed all 21 selected
checks. iOS 18 passed 85 selected unit/UI checks, including migration, detached
CSV sources, invoice-preserving visit correction/deletion, separate paid-invoice
deletion, and largest-text Horse deletion.

Physical iPhone 14 Pro / iOS 27 passed all four affected native UI flows:
referenced Service deletion at largest text, forced-save-failure alert with
rollback/relaunch/retry, invoiced Visit correction/deletion with retained invoice,
and separate paid-invoice deletion retaining the horse and visit.

Those checks exposed two additional issues, both fixed and reverified:
- A nested alert modifier suppressed deletion errors. The shared deletion sheet
  now sends errors to each screen's existing alert after native dismissal.
- Physical iOS resolves an existing photo root to `/var` while a missing file
  destination can retain `/private/var`. Containment now resolves the existing
  parent before comparing. Outside destinations, misleading sibling prefixes,
  and escaping file/directory symlinks remain rejected.

Final `xcodebuild test` results after these fixes:
- `/tmp/ff-deletion-photo-phone-fixed.xcresult`: 32 selected model/photo tests
  across three suites plus the native invoiced-visit correction/deletion flow;
  all passed on the connected iPhone, including photo cascade and rollback.
- `/tmp/ff-deletion-final18.xcresult`: 43 selected model/photo tests across five
  suites plus the native failure/rollback/relaunch/retry flow; all passed.
- `/tmp/ff-deletion-final26.xcresult`: the same 43 selected model/photo tests and
  native failure/rollback/relaunch/retry flow; all passed.

All runs were serial with parallel testing disabled and used isolated test data.
The string catalog dry-run and final diff whitespace check pass; no incumbent
localization entry was changed or removed. Earlier test assumptions and the two
real failures above were diagnosed before the final passing runs. This verifies
hosted synthetic sync contracts and native isolated-device behavior, not a live
two-device Apple-authenticated synchronization session. Local PostgreSQL was
stopped after validation; no database test server is retained.
