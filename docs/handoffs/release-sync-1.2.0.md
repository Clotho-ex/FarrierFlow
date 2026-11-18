# Release Backup & Sync acceptance — 1.2.0

## Current evidence

- During offline-edit acceptance on November 17, the owner's recorded-work note
  reached Production, but the open detail screen retained an older snapshot.
  `VisitDetailModel` now reads each reload through a fresh context; the existing
  editor-dismissal reload and immutable result snapshots stay in place. New
  persistent cross-context update/clear regression cases and the immediate
  Edit → Save Changes simulator assertion reproduced the bug before the fix.
  All 11 focused tests now pass, including note visibility before navigating
  away, persistence after relaunch and the saved invoice total. The screenshot
  is retained under `output/releases/1.2.0/review/visit-note-refresh/`.
  The corrected Release 1.2.0 (9) archive and distribution export succeeded.
  Actual archive/IPA configuration, strict signature and Apple entitlement
  checks passed; the distribution build has `get-task-allow=false` and contains
  no Debug fixture markers or private signing files. Build 9 is installed on the
  test iPhone. Readback verifies the retained Production binding, 33 records,
  one photo and its receipt, no pending upload/conflicts and database integrity.
  Build 8's archive is preserved. No build-9 upload or submission was performed.
- App Store Connect build 7 was uploaded without a cloud endpoint or public
  client key. Its archived Info.plist also has cloud-account deletion disabled.
- After the user's explicit $0/month approval, FarrierFlow Production
  (`msyoovsdvvjjifrzzzbq`) was created in `us-east-1`. Its initial public/private
  app schemas were empty. FarrierFlow Dev (`xufledziawaapvrifbfv`) and its data
  remain unchanged.
- The two canonical SQL schemas and `delete-cloud-account` Edge function are
  deployed. All 56 installed function bodies match the source fingerprints.
  Native Apple auth uses the exact app bundle ID; anonymous/phone auth and email
  sign-up are disabled. Live HTTP confirmed email sign-up rejection, anonymous
  bootstrap rejection, and exclusion of `ff_private` and `net` from the Data API.
- Nine rollback-only hosted contract suites passed: core sync, invoice history,
  protocol-three deletion, deletion worker, input bounds, visit workflow,
  deletion readiness, retry leases and retry scheduling.
  Two old fixtures were corrected to reject conflicting completion rather than
  saving unresolved progress. A final count-only query confirmed zero Auth
  users/sessions, workspaces, records, commits, photo manifests/objects and
  deletion jobs. These are SQL/authorization results, not live photo/Apple proof.
- `Configuration/App.Release.xcconfig` now uses Production's public endpoint/key.
  Debug still uses Dev. Xcode's native plist preprocessing keeps the deletion
  switch Boolean and separate per configuration. Release enables cloud deletion
  after backend verification; Debug retains its disabled switch.
- Release simulator build 1.2.0 (8) succeeded. Backup & Sync showed the enabled
  Apple button without Pro or an unconfigured warning. Continue Without Signing
  In persisted after relaunch, confirmed by the exact local-only preference.
  The final nine Debug configuration tests passed after the wiring change.
- All five Production Edge values are present. Public team/key ID fingerprints
  match the intended Apple configuration; the signing-key fingerprint matches
  the existing Dev key. Production encryption/worker fingerprints differ from
  Dev. No private value or `.p8` content was read. Seven live deletion HTTP
  route/authorization checks pass, including unknown-receipt non-disclosure.
- Both Production Vault entries are verified. The operator corrected the worker
  entry; Boolean-only readback confirms the original 43-character format and an
  exact SHA-256 match to the Edge secret, without returning a private value.
  `supabase/production/deletion_retry.sql` is installed. Its private dispatcher
  runs every minute, app roles cannot invoke it, and an idle queue makes no call.
  A no-job authenticated worker probe returned HTTP 200 with zero processed or
  completed jobs. This verifies scheduler credentials, not real account deletion.
- The final signed Release archive 1.2.0 (8) succeeded. Its actual Production
  endpoint, public key, Boolean deletion-on switch and native Apple entitlement
  pass the built-bundle gate; strict signature verification passes. It was
  installed over 1.1.0 (6) on the connected iPhone 14 Pro without uninstalling or
  erasing the app. Initial launch was denied because the phone locked. The owner
  then completed native Apple authorization successfully. Backup activation was
  blocked by the test phone's retained Development journal: its Development and
  Production user UUIDs differ, while SHA-256 fingerprints confirm the exact
  same Apple provider subject. Restoration and real cloud-account deletion
  remain unverified.
- A read-only phone database snapshot confirms the old Development binding, 32
  acknowledged records, and no pending upload, conflict, invoice-history archive,
  photo deletion or account-deletion fence. A prepared offline repair clears
  only the old sync journal and increments its optimistic-lock version. Every
  other table is unchanged and SQLite integrity passes. The owner explicitly
  approved this one-time test-device migration. It was applied with the app
  stopped; readback matched the prepared database exactly. Relaunch succeeded,
  Production created one workspace and the app uploaded all 32 business records.
  Every uploaded record's content hash matches the original acknowledged graph.
  The account-mismatch guards remain unchanged. Existing Development cloud data
  was neither deleted nor copied by an administrative server-side operation.
  The original database snapshot is retained privately for recovery while native
  acceptance continues.
- The owner added one non-sensitive photo through the Release app and reported
  backup success without error. Production now has 33 acknowledged records,
  including that photo. The saved iPhone JPEG is 1,747,955 bytes; its SHA-256
  matches the cloud manifest, its MD5 matches the storage object's ETag, and the
  record, manifest and storage object all report the same size. The bucket is
  private. The persisted phone journal has the Production binding, cursor 2,
  a matching verified-photo receipt, no pending upload and no conflicts; SQLite
  integrity passes. These checks verify native upload and saved protection
  metadata, not an authenticated download or restoration onto another phone.
  The app was stopped for a consistent checkpoint read and relaunched
  successfully. The owner confirmed that offline visit/photo viewing, sign-out
  with local records/photo retained, Apple sign-in again, and Sync Now all worked.
  Final independent readback still shows one Production workspace, 33 records,
  one photo manifest/object and zero deletion jobs. The final phone checkpoint
  retains the Production binding, cursor 2 and verified-photo receipt, with no
  pending upload or conflicts and a persisted successful sync. The test app was
  stopped after these checks; no simulator, build or test runner remains active.

## Owner-deferred checks — November 19, 2026

The owner explicitly chose not to perform second-iPhone restoration/photo
download or real cloud-account deletion before committing these changes. These
checks remain **not run**, not passed. The owner authorized the local commit
after review of the completed automated, configuration and native evidence.
No push, upload, metadata publication or review submission is authorized by
that instruction. Preserve the current local records and Production backup.

- The owner completed an offline recorded-work note edit and reconnected. A
  read-only Production query confirms the test note arrived on a `visitHorse`
  record. This closes the native offline-edit/upload check; the separate stale
  detail-screen regression found during that check is fixed and simulator-tested
  as described above.
- Authenticated photo download and clean restoration onto a second physical
  iPhone remain untested. Only one test iPhone is available. Do not erase the
  existing phone or treat sign-out/re-sign-in as restoration evidence.
- Real cloud-account deletion, including fresh Apple authorization, grant
  exchange/revocation, cleanup and retained local records, remains untested.
  The existing no-job worker probe and rollback-only contracts do not establish
  this. Deleting the current Production backup requires separate explicit owner
  approval; no such deletion has been requested or performed.

The Release configuration and the native checks above pass. The two checks
above are explicitly deferred by the owner; the commit does not establish
end-to-end restoration or real Apple-grant deletion acceptance.

## Final pre-commit verification — November 19, 2026

- Four configuration-gate regression tests passed again. The frozen build-9 IPA
  SHA-256, strict distribution signature, Production endpoint, Boolean deletion
  flag and Apple entitlement were verified. Saved result bundles confirm 11
  passing visit/detail/UI tests and 22 passing Release configuration/deletion
  tests; unchanged app code was not rebuilt or retested redundantly.
- Deployed deletion function version 6 is active; all six deployed TypeScript
  files match the repository exactly. The retry schedule remains active, private
  tables retain RLS with no direct app-role grants, and the dispatcher cannot be
  called by app roles. All five Edge secret fingerprints are present; the Vault
  worker format/fingerprint matches Edge without retrieving any private value.
- The read-only config diff has no differences for declared settings; nine
  remote-only defaults are intentionally unmanaged. Email/phone/anonymous
  sign-ups remain disabled and native Apple configuration matches the source.
- The current security advisor reports one password-protection warning and eight
  informational default-deny private-table notices. Password sign-ups are
  disabled; the app uses Apple authorization, so that warning does not describe
  an enabled app password flow. Do not change auth or billing to silence it.
  See [Supabase password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- Production retains one workspace, 33 records, one photo and no deletion jobs.
  No business/cloud data was changed by this verification. Generated release
  artifacts and private recovery snapshots remain local and excluded from Git.

## Release artifact and automated evidence

- App Store distribution export also succeeded. The exported IPA retains the
  correct Production configuration and Apple entitlement; its signature passes
  strict verification and `get-task-allow` is false. No Debug fixture markers,
  complete secret API keys or private signing-key files were found. Build 8 has
  not been uploaded or submitted; build 7 was the last verified uploaded draft
  candidate. Build 9 is the latest local corrected artifact as described above.
- Twenty-two focused Release configuration/deletion-controller tests passed,
  including the actual Release host's Production endpoint and deletion switch.
  The unrelated Debug-only showcase fixture test file was excluded by command;
  the first Release test compile failed on that fixture before this correction.
  Earlier security advisors returned zero errors or warnings; eight informational
  notices describe deliberately default-deny private RPC-only tables. The latest
  pre-commit check below records the unused password-flow warning separately.
- The built-bundle configuration gate is `scripts/validate-release-sync.py`.
  Its four focused regression tests pass. This is configuration-tool evidence,
  not evidence of hosted sync or Apple sign-in.
- The existing focused Swift configuration, Apple challenge/session, sync
  transport/runtime, photo transport and deletion suites passed on iPhone 17
  Pro / iOS 26.5: 85 tests, zero failures or skips. These use controlled local
  test transports, so they do not establish production service acceptance.
  The task simulator was shut down afterward; no test runner remains.

## Configuration and deployment sequence

1. Production project creation is complete. Preserve Debug's existing
   `App.Debug.xcconfig` / `Supabase.xcconfig` wiring.
2. The Production URL/public key were read back and wired through a
   separate Release xcconfig. Never put server secrets or signing keys in the application.
3. Deploy the existing reviewed sync and deletion contracts to the empty
   production project. Reconcile canonical SQL with the deployed Dev repairs;
   do not transfer any business data. Verify RLS, RPC permissions, private
   photo storage, authenticated Realtime and account-deletion fences.
4. Enable native Apple authentication for the exact FarrierFlow bundle ID.
   Configure the server-only Apple and deletion-worker secrets privately,
   following `solo-sync-apple-secrets.md` for the new production target.
   Verify presence/format only; never retrieve private values into chat.
5. Deploy the existing deletion function and production-specific retry
   scheduler. The existing Dev schedule hardcodes the Dev URL and must not be
   copied unchanged. Verify matching worker-key fingerprints without exposing
   the key. Keep app deletion disabled until its backend is operational.
6. Run rollback-only hosted authorization/graph/deletion contracts and live
   authenticated photo upload/download/hash/deletion checks using disposable
   test data. Verify cleanup and another owner's access denial.
7. Build Release, inspect its actual plist and signed entitlements, run the
   configuration gate with the verified production reference, and exercise
   Backup & Sync and account-free operation in the simulator after relaunch.
8. Separately validate native Apple sign-in, offline/reconnect sync, restoration
   and original photo integrity on two iPhones, plus fresh-Apple-proof cloud
   deletion that preserves local records. Simulator fixtures and synthetic SQL
   tests do not replace these acceptance checks.
9. A changed binary requires a new build number; preserve build 7's archive as
   evidence. Recheck App Store Connect for the next unused number before any
   replacement upload. Do not submit for review.

## Private operator setup for Production

Project: **FarrierFlow Production**, `msyoovsdvvjjifrzzzbq` (US East).
Use [Production Edge Function secrets](https://supabase.com/dashboard/project/msyoovsdvvjjifrzzzbq/functions/secrets).
Do not paste secret values into chat, source files or screenshots.

| Secret name | Enter privately |
| --- | --- |
| `FF_APPLE_TEAM_ID` | Already set by the agent to `5SN9TWDXQ4` |
| `FF_APPLE_KEY_ID` | The existing FarrierFlow Sign in with Apple key's ID |
| `FF_APPLE_SIGNING_PRIVATE_KEY` | That key's original `.p8` text, including real newlines |
| `FF_APPLE_TOKEN_ENCRYPTION_KEY` | New random 32-byte key, standard padded Base64 |
| `FF_DELETION_WORKER_KEY` | Separate new random 32-byte key, unpadded Base64url |

Reuse the existing Apple key for this same app; do not revoke or rotate it.
Keep the new Production encryption and worker keys in your password manager.
Generate these yourself in a private Terminal window if needed:

```sh
# FF_APPLE_TOKEN_ENCRYPTION_KEY
openssl rand -base64 32
# FF_DELETION_WORKER_KEY
openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n'
```

For the retry scheduler, also store the **same** worker-key value in
[Production Vault](https://supabase.com/dashboard/project/msyoovsdvvjjifrzzzbq/integrations/vault/secrets)
as `ff_deletion_worker_key`. The agent has already stored the Production public key as
`ff_deletion_publishable_key`; no operator entry is needed for it.
The public publishable key is not a server secret. Never use an administrative
key for that Vault entry or in the app.

The agent can verify names, digests and configuration behavior without
retrieving private values. See `solo-sync-apple-secrets.md` for the existing
operator-only handling rule and Apple key instructions.

## Validation commands

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s scripts/tests -p test_release_sync_configuration.py -v
python3 scripts/validate-release-sync.py /absolute/path/FarrierFlow.app \
  --project-ref VERIFIED_PRODUCTION_REFERENCE
```

The configuration gate rejects the Dev project, empty/unexpanded settings,
privileged keys, the wrong app and disabled/non-Boolean deletion configuration.
It does not authenticate to Supabase or establish Apple acceptance.

The November 19 instruction authorizes a local commit of the reviewed changes.
Submission, metadata publication, paid upgrade, secret rotation and push remain
outside this task.
