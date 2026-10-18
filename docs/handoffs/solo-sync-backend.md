# Solo sync backend — development evidence

Project: FarrierFlow Dev, `xufledziawaapvrifbfv`, East US (North Virginia).
Initial admin work used the user's existing Safari tab. The separately approved
2026-10-18 appointment-service update used the authenticated Supabase connector.
Only Debug includes the Dev Supabase configuration. Release deliberately has no
production project configured and fails closed; a successful Release compile is
not evidence of enabled production backup.

## Installed contract

`supabase/schemas/solo_sync.sql` is the version-controlled declarative source.
It was installed through the SQL editor after explicit action-time permission.
The project is not CLI-linked. The initial installation did not create a migration
history entry; the approved 2026-10-18 connector deployment recorded its actual
migration. Future schema changes must be non-destructive and reconciled with
this source.

The 15 business record kinds retain permanent UUIDs. Business data belongs to a
workspace, with current membership and a live Auth session required. Private
application tables have RLS and no direct client grants. Exposed RPC wrappers
are security invokers; tightly scoped internal functions use fixed search paths.
No service-role or secret key is placed in the iOS app.

Push operations acquire the workspace row lock, check record revisions and
operation fingerprints, validate the resulting graph and insert a commit in the
same transaction. Commit cursors therefore follow workspace commit order.
Issued invoice snapshots and tombstones cannot be overwritten. One designated
device/generation can issue invoices; a replacement can explicitly take over.
Old offline-device pending invoices are not silently discarded or renumbered.

`farrierflow-photos` is a private, JPEG-only bucket. Access checks workspace
membership and the photo record. Canonical objects cannot be overwritten by
client upsert. The manifest acknowledges size and hash after transfer; the
client must still validate downloaded JPEG bytes and hash.

Private Realtime broadcasts contain only a revision invalidation, not business
content. A missing notification cannot advance a cursor or mark data protected.
Refetch on launch, foreground, reconnect and notification is mandatory. See
[current broadcast documentation](https://supabase.com/docs/guides/realtime/broadcast).

## Hosted verification on 2026-10-13

Before installation, Safari's read-only probe returned no sync push/pull
functions and zero public tables. The native SHA-256 SQL function was present.
Installation returned `Success. No rows returned`.

The initial 121-line `supabase/tests/solo_sync_contract.sql` ran through Safari
with synthetic Auth users/sessions, then rolled back. It checked endpoint existence/permissions,
RLS, no direct writes, invoker wrappers, private bucket, owner pull, idempotent
receipt, stale revision denial, another owner's denial and revoked-session
denial. A separate cleanup query returned zero workspaces, records, commits,
synthetic users and photograph objects.

The expanded paid-GBP graph test exposed a decimal-date regex error. The
canonical source was corrected and the minimal `supabase/repairs/2026-10-13-date-validation.sql`
was applied successfully through Safari. After the Mac was unlocked, the expanded
rerun's result showed `23514: Horse outside appointment location`: the server
incorrectly applied today's horse location to completed visit history.
`supabase/repairs/2026-10-13-completed-visit-location.sql` was applied successfully,
preserving location validation for unfinished appointments. The current 213-line
suite then returned `PASS: solo sync contract; synthetic data rolled back`.
This verifies all 15 business kinds in a paid GBP graph, preserved completed
history after a horse moves, immutable invoice numbering, unfinished-location
denial, and atomic rejection alongside the original authorization tests.
A separate cleanup readback returned zero workspaces, records, commits,
synthetic users and photograph objects after the expanded run; the installed
validator repair was also read back.

The subsequent 482-line suite also passed via Safari: pending Visit work,
second-device registration, explicit generation-checked takeover, stale-device
invoice denial, unpaid complete snapshot deletion after payment reversal, paid
and partial snapshot deletion denial, cross-workspace relationships, private
photo access, and immediate deletion fences while the JWT session remains live.
The approved photo-cleanup repair uses operation-aware Storage SELECT only for
the owner's delete requests; downloads of tombstoned photos stay denied. Its
confirmation RPC rejects surviving objects and confirms absence idempotently.
Final cleanup readback returned zero workspaces, records, commits, photo
manifests, deletion jobs, synthetic users and photo objects; anonymous cleanup
RPC access is denied. This is synthetic database/RLS evidence, not a live JPEG
Storage upload/delete or completed account-deletion worker test.

Security advisors reported zero errors and two warnings on the project-generated
`public.rls_auto_enable()` helper. Its source was inspected; the warnings remain unresolved;
the advisor state is not described as clean.

Apple provider was saved and reopened enabled with sole audience
`com.farrierflow.yusufcan.FarrierFlow`. OAuth secret remains unset; native iOS
ID-token authentication does not use that web OAuth secret.

The Apple App ID capability was subsequently enabled and read back for exact
bundle `com.farrierflow.yusufcan.FarrierFlow`, team `5SN9TWDXQ4`, using primary
Apple consent. Existing IAP, push, and iCloud capabilities were preserved.
Local entitlements and simulated-entitlement generation are verified, not
physical provisioning or real Apple sign-in.

## Dev deletion worker — deployed; Dev configuration verified on 2026-10-14

The desired schema includes `supabase/schemas/deletion_worker.sql`. Its contract
is installed in Dev through the guarded incremental installation
`supabase/repairs/2026-10-13-deletion-worker.sql`. It refuses existing jobs or
unexpected previously installed worker state. It does not replace the baseline
schema or modify existing business content.

After explicit installation/test approval, the guarded worker schema was
installed through Safari in Dev. Hosted testing exposed PostgreSQL's regex
repetition bound; the ciphertext envelope now uses a separate bounded length
check and character validation. The minimal repair is saved in
`supabase/repairs/2026-10-13-deletion-token-validation.sql` and installed.
The fixture now uses a savepoint rollback for synthetic photo presence, rather
than bypassing Storage's protected-delete trigger. The 131-line deletion-worker
contract and the current 475-line solo-sync regression both returned explicit
PASS results. These are SQL/metadata tests, not real Apple or JPEG-byte cleanup.
Separate Dev readback confirms zero synthetic users, workspaces, records,
photo objects, jobs and receipts, the corrected validator, denied client queue
access, service-only claims, and zero private definers with unsafe search paths.
The legacy unverified deletion RPC is denied.

A fresh source review found retry starvation and permanent photo checkpoints;
both were independently reproduced. The installed recovery repair is
`supabase/repairs/2026-10-13-deletion-retry-recovery.sql`. Claims now rotate by
last attempt, readiness rechecks actual Storage absence, and owner-only upload
authorization holds a workspace share lock against deletion queueing. Separate
rollback-only retry/readiness contracts, the worker contract and full sync
contract all returned PASS after the repair. A lease-comparison fixture bug was
corrected by refreshing its temporary row; no platform protections were bypassed.
Separate readback confirms zero synthetic users/workspaces/records/photos/jobs/
receipts, the retry index, locking upload policy and denied anonymous helper access.

The dependency-free Edge-function source has 22 passing local Node tests and a
passing Deno 2.5.6 type check of the actual entry point. Tests exercise real
Web Crypto with synthetic keys and injected HTTP responses. They verify fresh
nonce-bound Apple proof, immutable owner identity, encrypted refresh-token
storage, receipt recovery after Auth deletion, leased exact-path Storage
cleanup, retryable failures, and Auth removal last. They do not prove real
Apple revocation or hosted object-byte cleanup.

After explicit deployment approval, `delete-cloud-account` was deployed through
Safari and updated with unconditional bounded photo re-draining on every retry.
The saved legacy-JWT setting is read back OFF; custom route authentication is
mandatory. A fresh ZIP downloaded from function Settings (not the editor export)
matches all six local source files byte-for-byte. Current worker SHA-256 is
`5b3bb44062ba321fd0a7b1d49a7ccfaf552570840daa4f2aa8a7f0e96fda1ed3`.
A non-destructive dashboard POST probe returned 503 with only
`{"error":"deletion_unavailable"}` before private configuration. This proves
the published entry point boots and fails closed, not working Apple deletion.
Safari's reload was initially blocked by a native leave-page dialog, not a
confirmed machine-lock problem; verification resumed after that dialog cleared.

Native deletion confirmation/progress and matching-account cold retry are
implemented. Unknown sends retain a device receipt; accepted jobs durably fence
the original store. Only completed receipts retire. Completion after an empty
reinstall works without mutating a discarded old store; the original bound store
retains its identity/fence. Local invoices and business/photo data remain usable.
At that deletion checkpoint, the relevant matrix passed 243 tests across 32
suites on both iOS 18 and iOS 26, with one physical-only protection test skipped
on each. Seven UI tests passed; Light/Dark/XXXL screenshots were also inspected. Accessibility hierarchy
tools returned application-only, so VoiceOver hierarchy acceptance is not claimed.
Release simulator build passed on the serial rerun after an agent-interrupted
overlapping first invocation. No archive, release, commit or push was performed.

The final restored-store regression also confirms that completing another
account/workspace's device receipt cannot label this business's pending deletion
as complete. Its original pending fence remains unchanged. The regression was
observed failing before the correction, then passed in both latest matrices.

At the initial deletion-worker checkpoint, scheduler source was prepared but
not installed. Safari readback showed
`supabase_vault` 0.3.1 installed; `pg_cron` and `pg_net` are available but not
installed. Its separate approval must cover enabling those extensions and the
minute retry job. Idle jobs do not invoke the Edge function. The operator must
privately configure the Apple key, encryption key, and narrowly scoped worker
key as described in [the private operator handoff](solo-sync-apple-secrets.md).

### Dev credentials and retry schedule — 2026-10-14

The operator entered all five Edge secrets privately and added two account MFA
methods. Seven synthetic HTTP route checks passed after configuration, including
unknown-receipt non-disclosure and rejection of missing session/worker proof,
malformed JSON shapes, wrong method and wrong content type. No private values
were inspected. This checks configuration shape, not Apple acceptance of the key.

Vault initially contained password-mask bullets instead of the worker key.
Boolean-only format/fingerprint probes identified the cause. The operator then
generated one replacement worker key privately and saved it in both locations;
its Edge fingerprint and Vault hash matched. Apple and encryption keys were
unchanged. Both Vault names were unique; the public key matched the Dev app.

After the explicit Dev installation request, `pg_cron`, `pg_net` and
`farrierflow-deletion-retry` job 1 were installed through Safari. The job is active
as `postgres`, runs every minute, and invokes only
`ff_private.dispatch_deletion_retry()`. The source now refuses any existing
deletion jobs before installation. App roles cannot execute the dispatcher.

A queue-privilege regression failed: hosted `pg_net` gives PUBLIC table access.
An attempted REVOKE had no effect because `supabase_admin` owns those grants.
No credential-bearing HTTP request had been committed at that point. These
platform grants cannot be changed through supported project SQL; do not claim
the queue is unreadable to database logins. All ten live LOGIN roles were
Supabase-standard roles, while `anon`, `authenticated` and `service_role` were
NOLOGIN. A live publishable-key request using `Accept-Profile: net` returned
406/PGRST106, confirming that the app API does not expose the HTTP queue.
Keep `net` unexposed and direct database access restricted to trusted operators;
queued headers contain the worker credential temporarily. See
[Supabase's platform constraint](https://supabase.com/docs/guides/troubleshooting/revoking-access-to-pg_net-objects-has-no-effect-0bbc16).

The new `supabase/tests/deletion_schedule_contract.sql` passed through Safari:
idle and completed jobs skip HTTP, active leases skip dispatch, pending/expired
leases enqueue the exact Dev route, empty body and Vault-backed headers, and
app-role dispatcher access is denied. Synthetic jobs and queued requests rolled
back without invoking the worker. The existing fair-retry contract also passed.
One separate no-job HTTP probe, request 3, returned 200 with processed=0,
completed=0, no timeout and no transport error. This proves the replacement
worker key is accepted by the deployed route, not real account deletion.

Fresh cron readback recorded 11 successful scheduled runs and zero failures,
with last success `2026-10-14 10:58:00.061453+00`. Independent final counts were
zero for workspaces, records, commits, photo manifests, deletion jobs, receipts,
Auth users and queued HTTP requests. A cleanup probe's incorrect `photos`
table name was corrected to `photo_manifest` before that successful readback.

Security advisors were rerun: zero errors, three warnings and eight informational
items. Two warnings are the existing `public.rls_auto_enable()` helper; the new
warning is `pg_net` extension placement in `public`. Optional recreation was
prepared but canceled, so no extension or response data was dropped. New
installations use `WITH SCHEMA extensions`; existing Dev placement is unchanged
and relocation requires separate approval. No ineffective REVOKE is retained
in source. Production, the app deletion-enable switch, real Apple revocation and
physical-iPhone acceptance are unchanged.

### Approved Dev pg_net relocation — 2026-10-14

After separate operator approval, the guarded
`supabase/repairs/2026-10-14-pg-net-placement.sql` was applied through Safari.
Preflight found no deletion jobs or queued requests and only the disposable
request-3 empty-worker response. Recreation moved `pg_net` from `public` to
`extensions` at the same version, 0.20.4. Transactional assertions confirmed
the entire retry-job row and dispatcher definition were unchanged. No CASCADE
was used. Only the prior synthetic HTTP response was removed by recreation;
no business records or credentials were changed.

A fresh authenticated no-job probe (request 1, submitted at
`2026-10-14 11:20:59.461979+00`) returned HTTP 200 with processed=0 and
completed=0. Subsequent readback showed one successful actual scheduled run
after that timestamp and zero failures; original job 1 remained active.
The focused scheduler contract passed, including placement, denied app-role
execution, idle/completed skips, live-lease skips and pending/expired dispatch.
Its synthetic fixtures and HTTP requests rolled back. Independent counts were
zero for workspaces, records, commits, photo manifests, deletion jobs, receipts,
Auth users and queued requests.

The live publishable-key `Accept-Profile: net` probe again returned
406/PGRST106. Rerunning Security Advisor showed zero errors, two existing
`public.rls_auto_enable()` warnings and eight informational items: the
`pg_net` placement warning is resolved. Relocation does not change hosted
`net` grants or make queued headers unreadable to trusted database operators.
Production, app deletion enablement and real Apple/device acceptance remain
unchanged.

## Held-history recovery and protocol 2 — current development

The reviewed repair `supabase/repairs/2026-10-13-invoice-history-protocol.sql`
was installed in Dev via Safari. Version-2 bootstrap/push/pull, owner grants,
private invoker core denial and the workspace minimum were read back. The
expanded invoice-history rollback contract passed, including inherited solo
ownership/photo/deletion boundaries, same-batch holds/new billing refusal,
clear/replace denial, permanent tombstones, exact legacy replay after minimum 2,
and changed-payload/protocol-relabeled receipt denial.

A genuine two-session Dev race passed: session B read unheld work before session
A committed, waited for its workspace lock, then received FF_ALREADY_BILLED;
no attempted invoice/group/line survived. A committed invoice winning before an
unacknowledged hold is still valid existing history, not silently discarded.
The exact disposable file and auto-created empty-folder placeholder were removed
through official Storage UI; scoped cleanup returned PASS. Independent SQL
readback confirmed zero fixture users, workspaces, records, photos, jobs and
receipts. Storage direct-delete protections were not bypassed.

V4 local recovery, immutable archive/independent PDF reader, explicit settings
review and truthful local-only counts are implemented. On-disk read-only save
failure rollback and repeated recovery reopen pass. The sync codec's named
aggregate-payment restoration exception preserves ordinary payment-use-case
restrictions. A simulator runtime check found a buffered temporary-context save
notification crash. Synchronous publication filtering fixes it; its regression
and actual iOS 26 confirmation/back/relaunch/PDF export pass. Read-only archive
contexts also explicitly disable autosave.

Fresh whole-feature review found two ordinary dependency-conflict variants and
repeated archive reconstruction. Regression REDs reproduced them. General
deferred transactions now receive explicit record choices and complete-graph
validation, including after local repair, without being misrouted to invoice
recovery. Original binding/journal/graph checks and permanent tombstones remain.
Eight conflict regressions passed; the follow-up read-only review found no further
Critical/Important finding in this delta. Archive list reading projects each
archive once; selected detail reading projects only its own archive. Six history
model tests passed, including projection counts and no temporary-save publication.
Both final unit matrices passed 742 tests in 111 suites on iOS 18 and iOS 26.5,
with one physical-only file-protection test skipped on each. The iOS 18 deep-stack
collection layout loop also affected review, not just history. Both now use
native independent-stack sheets, sharing the same models and atomic save paths;
iOS 26 retains native push routes. All nine final backup/recovery UI tests pass
on each OS. An additional iOS 18 Dark/accessibility5 test passes history from
both Backup and Invoices, read-only detail/PDF sharing, native return navigation,
and a same-store relaunch with both fixture reseeders removed. Its actual
screenshots were inspected. The first attempt queried a virtualized row below
the full-screen explanation; bounded scrolling corrected the test, not product
code. The equivalent iOS 26 test also passes. Its system share UI needed an
explicit dismissal wait before Back; recorded touch/hierarchy evidence also
exposed missed short native control taps. The finalized test uses ordinary
150ms presses for menu controls and the modern tab center, with bounded,
observed-state retry. No product behavior was changed for those test issues.
The finalized helper also passes on iOS 18 (122.2 seconds), and the unsigned
generic-iPhone Release build returns `BUILD SUCCEEDED`. No archive or release
was produced. The verification ledger is
`.superpowers/sdd/2026-10-13-held-invoice-history/progress.md`.

Fresh Safari rollback-only deletion-worker and fair-retry contracts passed
after the protocol repair. Independent readback found zero synthetic users,
workspaces, records, photos, jobs, commits and deletion receipts, with anonymous
version-2 push denied. The genuine hold-first concurrent race and one-time billing
checks above are complete; this is not authenticated HTTP or live Storage-byte
acceptance. The task-owned additional Safari tab was closed, preserving the
user's original tabs.

`supabase/tests/sync_input_bounds_contract.sql` subsequently passed through
Safari in Dev: both exposed protocol routes reject SQL/JSON null, non-object and
missing/non-array/empty/10,001-item mutations, a body over 10 MiB, and missing
identities, with unchanged workspace/record/commit counts. These twenty negative
RPC checks run as authenticated within a rollback-only transaction. Independent
readback again shows all seven fixture/application counts zero and anonymous
v2 push denied. No business writes, grants or server protections were changed.

At the protocol-2 checkpoint, performance advisor rerun reported zero errors,
warnings or suggestions. Security advisor reported zero errors, two warnings for the project-generated
`public.rls_auto_enable()` event-trigger helper, and eight informational no-policy
items for intentionally default-deny RPC-only private tables. Readback confirms
the helper is bound to an event trigger and authenticated public-schema CREATE
is denied. No helper permissions were changed; the two warnings remain.

### Physical Dev sign-in and upload checkpoint — 2026-10-14

The operator completed native Apple sign-in on the connected iPhone 14 Pro
(iOS 27.0). Fresh Safari count-only readback confirmed one Apple-backed Auth
user, one session, one owner workspace/membership and one registered device.
After the operator created disposable visit data and a photo, fresh readback
confirmed 11 active records, 11 sync commits, one photo manifest and one Storage
object. The manifest/record/object byte counts matched and Storage metadata
identified JPEG; the retry schedule was active and no deletion job existed.
This proves authenticated record and photo upload, not independent downloaded
byte verification, restoration, Apple grant exchange or revocation.

The initial direct device launch did not activate the Xcode scheme's StoreKit
configuration, leaving the operator unable to create records without Pro.
Relaunch through Xcode loaded both products; the operator then reported a
successful local test subscription, active Pro and working Add controls.
The separately reported read-only My Business scrolling issue is not fixed by
that test setup.

After explicit approval, `FarrierFlow-DevDeletion` provides a separate Debug
launch scheme with the existing StoreKit file and
`FARRIERFLOW_DEV_CLOUD_DELETION_TEST=1`. The override is compiled only in Debug
and requires the exact Dev host. Normal launches still use the existing explicit
Boolean flag, which remains false; Release ignores the test environment flag.
New configuration tests first failed for the missing policy API, then 17 focused
configuration/model tests passed. Direct Debug and Release compilation probes
passed, and the full unsigned iPhone Release build passed with the built plist
flag still false. No server authentication or authorization was changed.
The signed Debug build passed signature verification and launched on the paired
iPhone through Xcode after the operator unlocked it. The normal scheme remained
unchanged; the test scheme's explicit opt-in and StoreKit selection were read
back in Xcode. The test build does not submit deletion without the user's native
confirmation and fresh Apple proof. Live deletion acceptance remains pending.

### Remaining release acceptance

- Approve and configure a production project and its Release publishable settings;
  Dev configuration must not be silently shipped as production.
- Verify the Data API as a real authenticated client.
- Perform live hosted photo transfer/cleanup tests. Local SDK requests,
  JPEG/hash validation, interrupted-transfer recovery, same-store receipts and
  shared local storage coordination are tested; this is not live-cloud evidence.
- Verify the Dev Apple credentials against real authorization-code exchange and
  revocation; server-only configuration and the retry schedule are installed,
  but real Apple acceptance is not proved. Never paste credentials into source
  or chat. The normal app's deletion enablement flag remains off. No real
  account was deleted; live Apple and Storage-byte cleanup/concurrency remain
  release gates. The Dev extension-placement warning was resolved on 2026-10-14.
- Perform physical Apple sign-in/revocation and real two-iPhone offline,
  reconnect, restoration, conflict and photo verification before release.

This document is development evidence, not a claim that backup/sync is complete
or that the feature is ready to ship.

Approved held-history Tasks 1–6 are implemented and verified. Current evidence:
742 tests/111 suites on each OS (one deferred physical-only skip each), nine-test
backup/recovery UI matrices plus one expanded Dark/XXXL/both-entry/relaunch test
on each OS, 22 local worker tests, unsigned Release device compilation, catalog
JSON parsing and tracked/untracked-source whitespace/diff review. The fresh
whole-feature source review's findings were independently reproduced and fixed;
no Critical/Important source finding remains in the reviewed scope. XCTest
supplied actual native hierarchy queries and saved screenshots; actual VoiceOver
navigation/auditory acceptance is not claimed. Task-owned app/runners completed;
pre-existing simulators and user-owned development sessions are preserved.

## Appointment service planning — installed 2026-10-18

The operator explicitly authorized the reviewed cloud update and publication.
The Supabase connector applied migration `20261018132816`
(`appointment_service_planning`) to
FarrierFlow Dev, replacing only `ff_private.kind_schema`, `validate_fields`,
`validate_graph` and `sync_push_versioned`. Each hosted function body matched
the pre-change source before application. The generated, non-destructive repair
is preserved in `supabase/repairs/2026-10-18-appointment-service-planning.sql`.

AppointmentHorse accepts the optional `plannedService` Service UUID, including
legacy records that omit it. New clients send explicit null when clearing an
override. An older client cannot erase an existing non-null plan by omitting
that field. Workspace relationship validation still rejects missing or foreign
Service records. Authentication, grants, RLS and existing business data were
not changed.

Both `appointment_service_contract.sql` and the complete `solo_sync_contract.sql`
passed on the hosted project with synthetic fixtures rolled back. Local Swift
verification passed 754 unit cases on iOS 26.5 (753 passed, one physical-only
skip), 62 focused migration/persistence/model cases on iOS 18, and keyboard,
service selection, relaunch, visit prefill, actual largest-text Dark Mode and
nested first-service UI flows. This update does not close the production or
physical-device release acceptance gates above.

Post-deployment readback matched all four source function bodies exactly.
Independent queries confirmed the migration record exists and zero synthetic
Auth users or records remain. Performance Advisor reported no findings. Security
Advisor retains the existing public event-trigger helper execute warnings
([anonymous](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable),
[authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)),
eight informational default-deny private-table entries, and an Auth
[leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
warning. This deployment changed no helper grants or Auth settings.
