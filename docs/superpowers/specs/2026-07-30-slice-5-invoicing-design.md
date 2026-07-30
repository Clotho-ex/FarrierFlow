# Slice 5 — Invoicing Design

**Status:** Approved product and architecture design

**Date:** 2026-07-30

## Purpose

Slice 5 turns completed, priced work into a durable client invoice and a clean,
shareable PDF without requiring a network connection.

A farrier can:

1. Maintain one reusable Business Profile.
2. Start an invoice from Client Detail.
3. Select one or more eligible completed Visits, including Select All.
4. Generate an immutable numbered invoice.
5. Share a native US Letter PDF.
6. Mark the invoice Paid or delete it while it remains Unpaid.

This slice includes only simple Unpaid/Paid tracking. It does not process
payments or add a broader accounts-receivable workflow. It supersedes the
roadmap's high-level Slice 6 placeholder for binary payment status; no
additional payment-status behavior is implied.

## Product Boundary

- One Invoice belongs to exactly one Client.
- One Invoice contains one or more InvoiceVisits for completed source Visits.
- A completed Visit may appear on separate Invoices for different represented
  Clients.
- Each source WorkItem appears on at most one InvoiceLineItem.
- Selecting a Visit includes every eligible WorkItem for the Invoice's Client
  in that Visit. There is no per-Service or partial line-item selection.
- Invoice content is a snapshot. Later edits to Client, Business Profile,
  Horse, Service, or current service-location records never rewrite it.
- Invoice generation, numbering, source WorkItem billing links, and snapshot
  insertion are one atomic persistence action.
- FarrierFlow remains local-first and fully usable offline.

An eligible Visit must:

- Be completed.
- Contain at least one valid, uninvoiced WorkItem owned by a VisitHorse whose
  Horse belongs to the Client receiving the Invoice.

Mixed-client Visits are eligible independently for every represented Client
with at least one eligible WorkItem. WorkItems belonging to other Clients are
not included, marked invoiced, or changed. A Visit may remain eligible for
another Client after one Client's portion has been invoiced.

## Navigation and Workflow

No new tab is added.

- Client Detail provides **Create Invoice**.
- Clients > More provides **Invoices** and **Business Profile** beside the
  existing destinations.
- Invoices opens a native list of all Invoices.
- Business Profile opens its editor directly.

Create Invoice uses a native form:

1. If no valid Business Profile exists, require the farrier to complete it,
   then return to invoice creation.
2. Show the selected Client as read-only.
3. List eligible completed Visits by Visit date and service location. Each row
   represents all currently eligible WorkItems for this Client in that Visit.
4. Support individual Visit selection and **Select All**. Select All selects
   every eligible Visit for the Client; neither action exposes individual
   Service or line-item selection.
5. Set Invoice Date to the current date.
6. Preselect an optional Due Date 14 calendar days after Invoice Date; the
   farrier may clear it before generation.
7. Prepopulate the optional Note from the Business Profile's default invoice
   note; the farrier may edit or clear it for this Invoice.
8. Generate only when at least one Visit is selected and the full snapshot
   graph validates.

There is no Draft state. Cancelling discards the transient form. Successful
generation opens Invoice Detail.

## Business Profile

FarrierFlow stores one editable Business Profile:

| Field | Contract |
| --- | --- |
| Business or farrier name | Required normalized nonempty text |
| Phone | Optional normalized text |
| Email | Optional normalized text |
| Address | Optional normalized text |
| Default invoice note | Optional normalized text |
| Next invoice number | Required positive sequence value; not user-editable |

Editing the Business Profile affects only future Invoices. Existing Invoice
snapshots and PDFs remain unchanged. The Business Profile cannot be deleted;
its optional fields may be cleared.

## Invoice Numbering

- The first successfully generated Invoice uses number `0001`.
- Each successful generation advances the sequence by one.
- The stored number is an integer; display uses at least four digits with
  leading zeros. Numbers above `9999` continue without truncation.
- Numbers are unique and never user-editable.
- Failed generation consumes no number because the sequence advance and
  Invoice save are one transaction.
- Deleting an Unpaid Invoice never decrements the sequence or makes its number
  reusable.
- Overflow or an invalid sequence blocks generation without partial data.

## Immutable Invoice Snapshot

Invoice generation copies the information required to display and reproduce
the Invoice without consulting mutable source records.

### Invoice

Persist:

- Invoice number.
- Invoice date.
- Optional due date.
- Optional invoice note.
- Status: `unpaid` or `paid`.
- Optional payment date, present only when Paid.
- Client relationship for ownership and navigation.
- Client name, phone, and email snapshots.
- Business name, phone, email, and address snapshots.
- Explicit `USD` currency code.

All Invoice, InvoiceVisit, and InvoiceLineItem snapshot fields, including
Invoice Date, Due Date, and Note, are immutable after generation. Only status
and payment date may change through Mark Paid.

### InvoiceVisit

Create one InvoiceVisit for each selected Visit. Persist:

- Source Visit relationship.
- Actual Visit date snapshot from `Visit.startedAt`.
- Service-location name and optional address snapshots.

One Invoice contains at most one InvoiceVisit for a given source Visit. The
source Visit relationship is not globally unique: the same Visit may have one
InvoiceVisit on separate Invoices for different Clients. InvoiceVisit groups
and snapshots the source Visit inside one Invoice; it does not enforce
whole-Visit billing ownership. InvoiceVisit owns its InvoiceLineItems.

### InvoiceLineItem

Create one InvoiceLineItem for every eligible, uninvoiced source WorkItem owned
by the Invoice's Client in the selected Visit. Persist:

- Source WorkItem relationship.
- Horse name snapshot.
- Service name snapshot.
- Nonnegative amount in `Int64` minor units.
- Explicit `USD` currency code.

The source WorkItem relationship is globally unique across InvoiceLineItems
and is the duplicate-billing boundary. At generation, its VisitHorse's Horse
must belong to the Invoice's Client. Creating an InvoiceLineItem does not
change or move the source WorkItem.

Quantity, unit price, tax, discount, and mutable descriptions are not added.
Line order is deterministic by horse name, service name, amount, and stable
persistent identity tie-breaks. Visit groups order by Visit date ascending,
then service-location name and stable identity.

Invoice total is derived from immutable line snapshots using checked `Int64`
addition. Generation fails atomically if any relationship, snapshot, amount,
currency, uniqueness rule, or total is invalid.

## Locking and Historical Integrity

Once any InvoiceLineItem references a WorkItem from a Visit:

- Completed Visit correction is unavailable.
- Outcomes, Work Notes, WorkItems, WorkItem Services, and WorkItem amounts
  cannot change.
- Invoice generation remains available for another Client's eligible,
  uninvoiced WorkItems from the same Visit while correction is locked.
- Client, Horse, Service, Business Profile, and service-location edits remain
  allowed because the Invoice uses snapshots.
- Read-only Visit Detail and existing Photo behavior remain available.

Deleting an Unpaid Invoice deletes only its InvoiceVisit and InvoiceLineItem
snapshots and clears only those InvoiceLineItems' source WorkItem billing
links. It never deletes Visits, WorkItems, Horses, Services, Clients, or
Photos.

After deletion, a Visit becomes correctable again only when no remaining
InvoiceLineItem references any of its WorkItems. Remaining InvoiceLineItems on
another Unpaid Invoice keep correction locked. Any remaining InvoiceLineItem
owned by a Paid Invoice keeps the affected Visit permanently locked because
the Paid Invoice cannot be deleted.

Paid Invoices cannot be edited or deleted. They remain permanent historical
records.

Client deletion is blocked while any Invoice references that Client. Invoice
snapshots never cascade from Client deletion.

## Status

New Invoices begin Unpaid.

**Mark Paid** performs one atomic update:

- Change status to Paid.
- Record the current date as the payment date.

Slice 5 does not support a custom payment date, reverting to Unpaid, partial
payment, payment method, or payment processing.

## Invoice List and Detail

The Invoice list uses a native `List`, ordered by Invoice number descending.
Each row shows:

- Formatted Invoice number.
- Client name snapshot.
- Invoice date.
- Checked localized total.
- Unpaid or Paid status in text, never by color alone.

Invoice Detail displays:

- Business and Client snapshot information.
- Invoice number, Invoice Date, optional Due Date, and status.
- Line items grouped by Visit date.
- Horse, Service, and localized USD amount for every line.
- Checked total.
- Optional note.
- Payment date when Paid.

Invoice Detail provides:

- **Share PDF** for Unpaid and Paid Invoices.
- **Mark Paid** only while Unpaid.
- Delete only while Unpaid, behind destructive confirmation.

## PDF and Sharing

Generate one PDF file on demand from persisted Invoice snapshots using native
Apple PDF drawing frameworks.

- Page size is US Letter, 612 by 792 points.
- The document includes business and Client information, Invoice metadata,
  Visit-grouped line items, total, optional note, and Paid status where
  applicable.
- Long content continues onto additional US Letter pages without clipping or
  shrinking below readable text sizes.
- The PDF uses a restrained black-and-white layout, system typography, clear
  hierarchy, and no logo or theme selection.
- The filename uses the formatted number, for example `Invoice-0001.pdf`, and
  contains no Client name.
- Regeneration from the same Invoice snapshot produces the same financial
  content.
- PDF generation failure leaves the Invoice unchanged and offers Retry.

Present the generated file with the native share sheet. Keep the temporary file
available until sharing completes, then remove it on a best-effort basis.
FarrierFlow does not upload, email, synchronize, or retain a separate canonical
PDF.

## Architecture and Persistence

Keep the established dependency direction:

```text
SwiftUI View
    ↓
@MainActor @Observable feature model
    ↓
Focused invoice rule or use case
    ↓
SwiftData ModelContext
```

- Invoices owns selection, generation, listing, detail, status, deletion, PDF
  rendering, and sharing.
- Clients owns the contextual Create Invoice entry.
- Core/Money supplies checked totals and localized USD formatting.
- Core/Persistence owns schema registration, relationships, delete rules, and
  complete-graph validation.
- PDF rendering consumes an immutable value assembled from Invoice snapshots;
  it does not fetch or mutate SwiftData while drawing.

Do not add a generalized billing engine, repository layer, charge protocol,
document framework, dependency-injection framework, or third-party package.

## First Shipping Schema

FarrierFlow has not shipped. Slice 5 defines the first shipping store schema.

- Consolidate the current product models and Slice 5 models into one first-
  shipping versioned schema.
- Do not implement migration stages, fixtures, or compatibility policy for
  pre-release V1–V4 stores.
- Development, preview, and test stores may be reset.
- After this schema ships, every later persisted change requires an explicit
  migration from this first shipping schema.

Production, preview, in-memory test, and temporary persistent-store containers
must register the same shipping schema.

## Failure Behavior

- Missing or invalid source relationships fail closed.
- Concurrent or repeated generation cannot place one source WorkItem on two
  InvoiceLineItems or issue the same Invoice number twice.
- A failed generation rolls back the Invoice, snapshots, source WorkItem
  billing links, and sequence change.
- A failed Mark Paid action leaves the Invoice Unpaid with no payment date.
- A failed delete leaves the Invoice, snapshots, and source WorkItem billing
  links intact.
- Invalid or overflowing persisted totals are shown as unavailable; they are
  never wrapped, approximated, or presented as valid.
- Errors use native alerts and preserve recoverable user selection where safe.

## Focused Verification

Implementation must prove:

- Business Profile validation and snapshot isolation.
- Atomic sequential numbering, including deletion without reuse.
- Per-Client Visit eligibility, Select All, automatic inclusion of every
  eligible Client WorkItem, and absence of per-line selection.
- Mixed-client Visits on separate Client Invoices while every source WorkItem
  remains globally unique across InvoiceLineItems.
- Complete WorkItem-to-InvoiceLineItem relationships, snapshots, and checked
  totals.
- Whole-Visit correction locking after any invoiced WorkItem while another
  Client's uninvoiced portion remains available for generation.
- Unpaid deletion releases only its WorkItem billing links; correction remains
  locked until no references remain, and Paid references lock permanently.
- Persistent-store reopening of Business Profile, Invoices, source
  relationships, status, payment date, and snapshots.
- Multi-page US Letter PDF generation and native sharing entry.
- The primary Client Detail → Generate → Share → Mark Paid flow on iOS 18 and
  iOS 26.

All verification remains serial under the repository's resource-constrained
policy.

## Explicit Exclusions

Slice 5 does not add:

- Taxes.
- Discounts.
- Tips, deposits, refunds, or adjustments.
- Partial payments.
- Payment processing.
- Payment methods.
- Overdue automation or notifications.
- Draft or Sent states.
- Recurring Invoices.
- Monthly statements.
- Multi-client Invoices.
- Custom Invoice numbering.
- Logos or Invoice themes.
- Estimates or quotes.
- Visit-level, travel, mileage, barn-call, emergency, or shared charges.
- Accounting integrations.
- Email delivery.
- Networking, accounts, CloudKit, synchronization, or app-managed backup.
- Third-party PDF dependencies.

## Specification Authorization

This specification authorizes design documentation only. It does not authorize
an implementation plan, schema changes, production code, builds, tests, or
publishing.
