# Reviewed local-only invoice history

## Purpose and approved policy

Extend the existing solo backup/sync feature so safe records can continue syncing
when independently issued invoices share a printed number, or an old invoicing
iPhone issued invoices offline after takeover. The user approved reviewed local-only
history on 2026-10-13. Original invoice numbers, UUIDs, currency, amounts, payments
and issued snapshots must remain intact and viewable/exportable. No silent
renumbering, deletion, currency conversion or lookalike identity collapse.

This is an architectural recovery addendum to the existing solo-sync design.
The retention policy and this revised storage/data-path design were approved by
the user on 2026-10-13. The written implementation plan still requires review
before code changes. No commits or releases are authorized.

Approved revision: 2026-10-13, incorporating the Luna High review's billing
identity, mixed-version safety and post-deletion archive-access findings. This
document specifies intended behavior; these recovery changes are not implemented.

## Selected approach

Store an immutable, versioned local archive inside the existing business store's
sync journal. Each archive contains the validated committed graph captured at
review time, the affected invoice UUIDs, reason, account/workspace binding,
source operation when applicable, and capture date. Copying the complete graph
keeps financial dependencies self-contained; only selected invoices are presented
as held history. The archive contains record metadata, not duplicate JPEG bytes.

Keeping duplicate invoices in the active SwiftData graph is rejected: its invoice
number and one-time-billing constraints protect normal invoicing. Pausing all sync
was the alternative the user declined. The archive remains outside cloud batches.

### Exact-identity billing safeguard

Each affected source WorkItem that survives in the active graph receives an
optional `billingHoldID`. Its value is the original archived invoice UUID, not a
new UUID generated on retry. The archive records the exact invoice-to-WorkItem
UUID mapping. The fence is scoped to `(workspaceID, WorkItem UUID)`; neither
names, dates nor printed invoice numbers establish identity. The synced marker
contains no invoice number, amount, payment or issued snapshot. It is a validated
opaque UUID, not a foreign key requiring that local-only invoice to exist in the
active/cloud graph. Only the local archive carries the invoice/work mapping.

A non-null hold is permanent for that WorkItem identity. Local eligibility and
invoice creation both reject held work before consuming an invoice number. Cloud
commit validation rejects any new invoice line item referring to held work,
including a hold and new line item submitted together, regardless of client
version or invoicing-device authority. A cloud line item that already exists may
remain unchanged; it is not a newly issued line item. Mark affected work even
when such a cloud invoice remains active, so later removal of that invoice does
not make the work billable again. Existing invoice/payment protections remain.

Ordinary edits cannot clear or replace a hold. An existing hold retains its first
value; an additional local archive can reference the same work without replacing
that fence. Deleting a held WorkItem retains the permanent identity tombstone;
neither deletion nor an old payload can resurrect it as unheld work. The server
validates holds under the existing workspace commit lock and owner authorization,
so concurrent billing/hold operations cannot both pass against stale state.

This prevents rebilling the exact marked WorkItem on compatible phones, and
prevents acceptance of conflicting invoices into cloud history after the hold is
committed. It cannot equate separately initialized lookalikes, prevent another
app/manual invoice, or stop an older disconnected phone from printing locally.
Such invoices remain preserved for review; they are never silently renumbered or
discarded. No held invoice is counted as cloud-protected because its marker synced.

Adding the persisted optional WorkItem marker requires a new schema version,
not editing an already-created V3 store shape. Preserve V1/V2/V3 definitions and
all existing identities; validate lightweight upgrade and repeated reopen on both
iOS versions. The archive envelope itself remains versioned inside journal data.

### Safe sync-version rollout

Select an explicit version-2 sync contract for hold-aware clients, alongside the
existing contract. New clients accept valid pre-hold records as `billingHoldID =
nil`; they validate the new field strictly when present. Unknown fields/versions
still fail closed, rather than being ignored. Adding the field does not alter
the content or identity of an already-pending legacy operation.

The first accepted hold atomically raises that workspace's minimum sync protocol
to version 2. From then on, legacy clients cannot perform new commits or obtain a
pull that hides the holds. They must upgrade before continuing cloud sync. New
clients render an explicit update-required state when a contract is unsupported;
an already-built legacy client may only display its existing sync failure UI.
Never claim an older binary can understand a newly introduced error or marker.
The server rejects omitted/null/changed holds on held identities and new billing
against them; choosing a legacy route never bypasses the fence. All callers keep
the existing live-session, workspace ownership and designated-device checks.

Exact operation receipts remain recoverable through the original contract even
after the minimum version rises. Receipt identity/hash validation precedes the
version gate for a replay: a committed operation returns its original receipt;
an uncommitted incompatible operation gets a definitive rejection without any
partial write. Timeout, cancellation, lost acknowledgment or decode failure is
not a rejection. An upgraded app retries a pending operation with its original
operation ID, payload and contract before replacing it; only definitive rejection
permits retirement and review. No hidden field insertion or payload normalization
may change the operation that the client considers pending.

The compatibility handshake must still permit this narrow pending-operation
settlement path: an upgrade requirement cannot block receipt recovery before the
original operation is retried. It grants no exception for a new legacy commit or
pull. Only a matching authenticated workspace/device may recover its receipt.

Pulls are whole transactions. An unsupported graph never partly advances the
cursor or applies safe-looking records. Upgrading preserves local records,
archives, authority generations and the exact outbox. An old phone's offline
invoice remains local-only if rejected on catch-up, and needs the compatible app
to inspect and resolve it. Server fencing is not a promise of offline prevention.

Existing released versions are local-only, not deployed cloud-sync clients. This
contract is a pre-release and future rollout safeguard, not a claim of an existing
production incident. Deploying these changes is outside this design-only approval.

### Archive access independent of cloud availability

History reading uses a dedicated local archive reader, not the ordinary sync
journal API that rejects `cloudDeleted` stores. It reads the archive from the
same business store, validates its envelope/version and original binding, and
constructs an isolated read-only graph for the selected invoice. It requires no
active Apple session, cloud availability or successful sync. It neither clears
the deletion fence nor rebinds the business nor activates the cloud client.

Signing out, pending/completed cloud deletion, offline launch and subsequent
reopen leave the original invoices readable/exportable. A corrupt or unsupported
archive fails with a clear local-history error without changing business data,
dropping archive bytes or allowing invoice creation from that archive.

## Review and atomic recovery

1. Distinguish a confirmed server authority rejection from an ambiguous/lost
   response. Preserve the exact pending operation until rejection is proven.
2. Present the affected invoices and the canonical business settings. For a
   separately initialized profile, explicitly choose the active settings while
   preserving the cloud profile identity and designated-phone number authority.
   Do not infer that two differently identified clients or visits are duplicates.
3. Require explicit confirmation. Reject stale review, changed account/workspace,
   open drafts, or an invalid graph; no partial recovery is applied.
4. Save the complete archive and exact source-work mapping, apply all required
   holds and the validated active graph, and retire only definitively rejected
   operations in one local transaction. Any failure leaves the original live
   records, archive, holds and pending operation unchanged. A confirmed recovery
   persists the same archive/hold identities across reopen and retry.
5. Resume safe-record sync with new operation IDs. Ordinary remote application
   keeps its existing strict immutable-history and duplicate-number checks;
   only reviewed, durably archived invoices may leave the active graph.

Local recovery is atomic; it is not a distributed transaction with Supabase.
Until a hold is acknowledged, the UI says its billing safeguard is awaiting sync.
No protection claim is made during that interval. A concurrent cloud change
invalidates the review/expected revisions and requires refetch/review; it cannot
silently rewrite the archived invoice or clear a hold to force a merge.

Differing business currencies remain a fail-closed recovery condition. This
extension must not reinterpret prices or convert an existing business's amounts.
The user sees the reason and retains both histories; no automatic partial merge
is allowed where dependency validation cannot establish a safe active graph.

## User-facing behavior

- An Invoice History section exposes the held invoices separately from active
  invoices. A read-only detail view shows the original issued/payment snapshots.
- PDF export reuses the existing content builder/renderer through an isolated
  archive context. Printed numbers, financial content and currency are unchanged.
  Duplicate export filenames use separate temporary folders, not renumbering.
- No edit, delete, payment or ordinary billing action is offered in the archive.
  Exact held WorkItems are excluded from compatible-app invoice creation.
  Separately identified lookalikes and older offline phones are not presented as
  protected from local issuance; rejected invoices remain available for review.
- Backup status explicitly counts and labels held invoices as local-only and
  **not cloud-protected**. It must not claim the entire business is protected.
- Signing out or deleting the cloud account keeps this local history. Resetting
  or deleting the local business is outside this extension's scope.
- An incompatible sync version shows an upgrade requirement where the client
  supports that message; no partial restore or silent downgrade is offered.

## Validation required

- Paid and unpaid collision fixtures preserve UUIDs, exact Int64 amounts,
  original numbers, currencies, payment details and PDF content across reopen.
- Lost acknowledgment is retried exactly and never classified as a rejection.
- Stale-generation rejection, overlapping invoice numbers and duplicate billing
  links produce review; archiving and active-graph recovery are atomic.
- Hold identity matches the archived invoice and exact source-work mapping across
  retry/reopen. Held work is excluded from local selection and rechecked during
  creation without consuming a number. Existing cloud line items remain unchanged.
- Hosted rollback tests reject new billing against held work, including same-batch
  hold/billing, clear/replace attempts and old-version payloads. Concurrent commit
  tests verify stale billing/hold operations cannot both succeed. Deletion and
  resurrection attempts cannot remove the identity fence.
- Mixed-version tests cover pre-hold decoding, the atomic minimum-version change,
  legacy commit/pull refusal, whole-transaction cursor preservation, omitted/null
  holds, exact legacy receipt replay and rejection of old-phone offline invoices.
  Upgrade retains rejected invoices and never rewrites a lost-ack pending batch.
- Archive write failure, unsaved edit, stale review and account mismatch leave
  the original graph/outbox untouched. Reopening retains history and fences.
- Same-field conflicts and lookalikes retain existing conservative rules. Mixed
  currencies fail closed without conversion. Future workspace ownership is kept.
- Local-only counts stay truthful; read-only invoice/PDF access works without
  granting Pro mutation rights. Light/Dark/XXXL and iOS 18/iOS 26 are verified.
- Read-only history and original PDF content remain accessible while signed out,
  offline and after pending/completed cloud deletion, including repeated reopen.
  Corrupt/unknown archive versions fail visibly without deleting archive data or
  clearing a sync/deletion fence. Unacknowledged holds never imply cloud protection.

## Boundaries

iPhone only. No new dependency, cloud archive feature, automatic deduplication,
invoice-series redesign, team permissions, billing changes or publishing.
Actual Apple and two-iPhone acceptance remain deferred release gates.
