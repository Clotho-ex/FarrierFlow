# Business Currency Expansion Design

## Goal

Make FarrierFlow's business workflow safe for the existing United States and
Turkey storefronts and the planned United Kingdom, Ireland, Canada, Australia,
New Zealand, and South Africa storefronts.

## Supported currencies

FarrierFlow supports exactly these ISO 4217 business currencies in this slice:

- USD — United States dollar
- TRY — Turkish lira
- GBP — British pound
- EUR — euro
- CAD — Canadian dollar
- AUD — Australian dollar
- NZD — New Zealand dollar
- ZAR — South African rand

All supported currencies use two minor-unit digits. This slice performs no
currency conversion and stores no exchange rates.

## Ownership and defaults

`BusinessProfile` owns one required `currencyCode`. A new profile defaults to
the device locale's currency when that currency is supported, otherwise USD.
Business setup presents the detected choice so the owner can confirm or change
it before continuing. My Business presents the same native currency picker.

The selected business currency supplies new Services. Service currency flows
unchanged through WorkItems, immutable InvoiceLineItems, Invoices, Payments,
PDFs, and CSV monetary displays. StoreKit subscription currency remains
Apple-owned and independent from the business currency.

## Change safety

The business currency may change only while no Service, WorkItem, Invoice,
InvoiceLineItem, or Payment exists. The first such record locks it. FarrierFlow
does not relabel, convert, or rewrite existing money.

All stored business currency codes must be supported. When a BusinessProfile
exists, every Service, WorkItem, Invoice, InvoiceLineItem, and Payment must use
its currency. Existing same-currency relationship invariants continue to apply.

## Migration

The shipping `FarrierFlowSchemaV1` remains the prior schema. A complete
`FarrierFlowSchemaV2` adds required `BusinessProfile.currencyCode` with the
lightweight-migration default `USD`. The migration preserves all existing
records, relationships, integer amounts, invoice snapshots, and payment
evidence without conversion.

Production keeps the existing store identity. A persistent migration test must
create a V1 store, reopen it through the current V2 container, and prove the
profile defaults to USD while the existing graph survives.

## Entry, formatting, and documents

Money entry uses the current user locale's decimal and grouping separators and
accepts at most two fractional digits. Formatting uses the stored ISO currency
code and locale-aware system currency formatting. Zero retains the existing
localized `Complimentary` presentation.

PDF rendering and export accept every supported currency and fail closed for
unsupported or inconsistent codes. Existing invoice document structure and
paper size are unchanged in this slice.

## Interface

Use a native `Picker` in Business setup and My Business. When locked, show the
saved currency read-only with concise text explaining that prices and invoices
protect it from change. Service price helper and validation copy name the
selected ISO currency without adding a new settings destination.

The UI remains English-only for this release expansion. Additional translated
store metadata and app localization are separate future work.

## Release boundary

This unit prepares and validates the binary. It does not commit, push, upload,
submit, release, or change App Store territory or subscription availability.
Those actions require a separately verified release candidate and explicit
publication authorization.
