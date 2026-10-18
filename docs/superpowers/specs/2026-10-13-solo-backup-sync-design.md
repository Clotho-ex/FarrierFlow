# Solo backup and sync

## Approved outcome

Offer optional native Sign in with Apple to protect an independent farrier's
business records and hoof photographs, restore them on another iPhone, and
synchronize saved changes between that person's iPhones. Cloud protection is
available to every signed-in user independently of FarrierFlow Pro. Existing
subscription rules still govern ordinary business mutations.

The user approved this scope and asked to begin implementation. Existing
account-free operation and offline work remain available. The feature adds no
iPad, Mac, web client, team invitation, assignment, or team billing surface.

## Ownership and privacy

A business workspace owns records; an Apple-authenticated person has an owner
membership. This release supports one owner of one workspace. Server access is
checked against current membership, including on photo and Realtime requests.
Record relationships must stay inside the same workspace. Auth account deletion
must not implicitly cascade into another person's business data in a future
shared workspace.

Business content is processed for storage, restoration and synchronization,
never advertising or sale. Purchase processing and existing anonymous product
analytics remain separately disclosed. Do not identify the Apple user to
PostHog or send record contents, record IDs, workspace IDs, contacts, notes,
amounts or photo URLs in analytics. Request only necessary Apple scopes.
Encryption in transit/at rest must not be described as end-to-end encryption.

## Local persistence and record identity

SwiftData remains the local source for screens and saves. Preserve store name
`FarrierFlowV1`, V1 and V2 historical snapshots, all domain relationships,
financial snapshots, amounts, currencies, invoice numbers and photo filenames.

V3 gives every syncable record a permanent UUID. Existing Photograph and Payment
UUIDs remain their sync IDs. Other IDs use optional SwiftData storage for safe
additive migration, are initialized once during creation or V2-to-V3 migration,
and are required and checked for duplicates at the sync boundary. Reopening or
retrying migration never replaces established IDs. UUIDs assigned independently
to two pre-sync copies cannot establish that those copies are the same record.

Every successful local transaction must record its changed records/deletions
durably before it can be advertised as protected. An atomic outbox and account/
workspace binding belong to the same local store. An upload acknowledgment must
not erase a newer queued edit. Cursor advancement and applying a downloaded
transaction are atomic. Unsaved editor drafts remain unsaved.

## Sync contract

Use Supabase in East US (North Virginia), initially project
`xufledziawaapvrifbfv` (FarrierFlow Dev). Supabase setup and inspection use the
user's open Safari tab. No paid upgrade or unrelated project mutation is
authorized. The user approved the official Swift SDK, pinned to version 2.55.3.
Native Apple authentication is enabled with only the FarrierFlow bundle ID
`com.farrierflow.yusufcan.FarrierFlow` as its audience.

Use transactional bounded batches, operation UUIDs for idempotency, server
revisions for optimistic concurrency, and a commit-ordered workspace change
cursor. A sequence allocated before commit is insufficient as a change cursor.
Queries and writes enforce membership in the database, not client-supplied user
IDs. Realtime is an authenticated invalidation signal; refetch authorized data
after notification, launch, reconnect and foregrounding. iOS background time
is opportunistic; the interface never promises uninterrupted background sync.

Fetch and apply complete dependency groups; never expose partially restored
invoice/payment or appointment/visit graphs. Validate untrusted remote fields,
relationships, immutable history and checked monetary totals before saving.
Conflicting edits remain durable until resolved, with no silent last-writer loss.
Tombstones prevent a stale device from resurrecting deleted records.

UUID matches reconcile automatically when revisions permit. Independent
lookalikes are suggestions for explicit review; never infer identity from a
name, date, amount or invoice number. Existing issued invoice numbers and
snapshots are never silently renumbered. Concurrent numbering and one-time
billing require server constraints and one designated invoicing iPhone. That
phone retains offline issuance; other synced phones can edit schedules, visits,
photographs and payments but cannot issue invoices. A replacement phone can
explicitly take over online, advancing a server-owned device generation. Old
offline devices may still have pending invoices: retain those locally and
present their conflicts rather than silently dropping or renumbering them.
Account-free invoice generation retains its current behavior. Overlapping
existing invoice numbers need explicit resolution before importing a second
local history.

## Photographs

Upload the existing canonical normalized JPEG bytes without further lossy
recompression. Use a private bucket and workspace/photograph UUID paths.
Check metadata, byte length and content hash on transfer. Never use public
buckets for business photos or persist expiring signed URLs as record identity.
Use resumable/retry-safe uploads with bounded concurrency. Mark a photo
protected only after the object and metadata are acknowledged. Restore records
first and download photographs progressively into protected local storage,
coordinated with existing photo transactions and reconciliation.

## Optional account flow

Expose a native Backup & Sync destination in Clients > More and one dismissible
invitation after normal setup. Show backup, recovery, iPhone sync and offline
benefits, the privacy explanation, the native Apple button, and a visible
Continue Without Signing In action. Never block operational startup on Auth.

Show Local Only, pending changes, pending photos, last successful sync, progress,
retry and conflicts using observed state. Never show Synced from sign-in alone.
Restoring data and cloud reads work without a Pro entitlement.

Sign-out cancels account-owned requests, removes credentials and stops sync,
while preserving local business data and its binding. A different Apple account
cannot silently adopt those records. Explicit copy/adoption requires a separate
choice, and must not reuse private account state.

Delete Cloud Account requires fresh authentication and confirmation. Server
authorization is revoked before asynchronous object cleanup; database data,
Storage objects, sessions and Apple authorization are removed with a retryable
deletion job. Retain local business records on the initiating iPhone, disable
uploads, and prevent other devices from accidentally recreating the account's
deleted cloud dataset. Account deletion never cancels an Apple subscription.

## Durability and release evidence

Synchronization is a cloud replica, not recovery from every intentional deletion.
Describe device-loss recovery accurately. Supabase database backups do not
include Storage object bytes; operational recovery must verify separate object
protection before promising historical backup recovery or unlimited retention.

Verify real on-disk V1->V2->V3 and V2->V3 migration, repeated reopening, stable
IDs, graph preservation and rollback. Exercise offline saves, failed/retried
batches, duplicated acknowledgments, cursor pagination/commit races, two-device
edits, deletion resurrection, cross-workspace access denial, photo integrity,
sign-out/account switching and deletion with unexpired credentials.

Run focused tests during implementation, then the required iOS 18/iOS 26
integration matrix and native accessibility checks. Actual hosted Apple sign-in,
revocation and a two-iPhone restoration/sync journey are external acceptance
gates. An SDK fake or SQL success alone does not establish those behaviors.

## Authorization boundaries

No commits, pushes, portal release, App Store metadata changes, paid plan,
credential rotation or new production dependency without the applicable explicit
authorization. A browser operation creating security-sensitive access needs
action-time confirmation. Keep preparing and validating all unblocked local work
while such a decision is pending.
