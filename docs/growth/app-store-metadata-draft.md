# FarrierFlow App Store Metadata Draft

**Status:** Local draft only. Do not publish or edit the live v1.0 App Store
version while it is under review.

**Research date:** September 13, 2026 (United States storefront)

## Research basis

Apple allows a 30-character name, 30-character subtitle, 170-character
promotional text, 4,000-character description, and a keyword field of up to
100 bytes. Apple recommends relevant, non-duplicative keywords and prohibits
competing app names and unauthorized trademark terms in metadata. See
[App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information),
[platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information),
and [product-page guidance](https://developer.apple.com/app-store/product-page/).

Current US App Store listings confirm that customers in this category are
presented with language around scheduling, invoicing, clients, horses, visits,
hoof photos, due/overdue work, and running a farrier business. Sources reviewed:

- [Best Farrier](https://apps.apple.com/us/app/best-farrier/id1500314269)
- [Farrier Fleet](https://apps.apple.com/us/app/farrier-fleet/id6757606700)
- [HoofLedger: Farrier Manager](https://apps.apple.com/us/app/hoofledger-farrier-manager/id6790246458)
- [Shoein': Farrier Client Book](https://apps.apple.com/us/app/shoein-farrier-client-book/id6799500214)
- [EQUINET — Mustad Farrier App](https://apps.apple.com/us/app/equinet-mustad-farrier-app/id1459492568)

These listings establish vocabulary and competitive context only. Their names,
ratings, claims, and testimonials must not be copied into FarrierFlow metadata.

## App name strategy

**Recommended name:** `FarrierFlow` (11 bytes)

Keep the distinctive product name rather than stuffing a generic descriptor
into the title. The name already signals the trade and leaves the subtitle to
carry the highest-value functional intent. Revisit only if actual App Store
search data shows that the brand is not being tokenized for “farrier.”

Do not use competitor names, pricing, “best,” ranking claims, or unsupported
superlatives in the name.

## Subtitle

**Recommended:** `Farrier Scheduling & Invoicing` (30 bytes)

This uses the full allowance for two high-intent, implemented outcomes. It is
more search-oriented than the v1.0 draft `Farrier records and visits`, while
remaining accurate.

Alternative if Apple or localization review needs more room:
`Schedule Work. Send Invoices.`

## Keyword field

**Draft (89 bytes):**

```text
horse,hoof,client,barn,appointment,visit,business,management,service,shoeing,trim,payment
```

Rationale:

- Avoids duplicating `farrier`, `scheduling`, and `invoicing` from the name and
  subtitle.
- Uses singular forms and no spaces after commas to preserve the byte budget.
- Covers the actual appointment → visit → invoice → payment → next-appointment
  workflow and the horse/client/location record structure.
- Leaves 11 bytes for a later keyword learned from App Store Connect or Apple
  Ads rather than filling the field speculatively.

Before submission, verify the UTF-8 byte count in the final localization and
compare the draft against real App Store search-term data. Do not place
competitor or company names in this field.

## Categories

- **Primary: Business.** FarrierFlow directly supports running a business,
  including customer records, scheduling, field work, invoices, and payment
  status. This matches Apple's Business definition and the current v1.0
  selection.
- **Secondary: Productivity.** The product organizes a repeatable field-work
  process and calendar-driven tasks. This broadens accurate browse context
  without misclassifying FarrierFlow as Finance or a consumer horse-care app.

Apple describes Business as apps that assist with running a business and
Productivity as apps that make a process more organized or efficient. See
[Choosing a category](https://developer.apple.com/app-store/categories/).

## Promotional text

**Draft (138 characters):**

> Run the day from your iPhone: schedule appointments, record hoof work and photos, create invoices, mark payments, and plan the next visit.

This is outcome-led, current-product copy. Promotional text does not affect
search ranking, so do not turn it into a keyword list.

## Description structure

Use this order for the eventual v1.0.1 description. The current v1.0
subscription disclosure and links must remain accurate in the final text.

### 1. First sentence: complete field workflow

> FarrierFlow connects the working farrier's day—from the next appointment to horse history, completed work, hoof photos, invoices, payment status, and the next visit.

### 2. Field-work outcome

Explain that FarrierFlow helps an independent farrier see today's work, start a
visit from an appointment, record services and photos, complete the visit, and
carry that work into an invoice without returning to a generic feature list.

### 3. Connected records

Use concise bullets covering only shipped functionality:

- Organize clients, horses, service locations, and services.
- Schedule appointments and review upcoming work.
- Record single- or multi-horse visits and hoof photographs.
- Create and share invoice PDFs from completed work.
- Record payment status and evidence.
- Plan the next appointment from the completed visit.

### 4. Local-first privacy and continuity

State that core business records stay on the iPhone, no FarrierFlow account is
required, and the app does not upload record contents as analytics. Do not say
that no data ever leaves the device; v1.0.1 uses PostHog, RevenueCat, and Apple
AdServices as disclosed in the Privacy Policy.

### 5. Subscription and read-only access

Retain the truthful FarrierFlow Pro auto-renewal disclosure. State that active
Pro access is required to create or edit records, while meaningful existing
records, photographs, history, and invoice PDFs remain available read-only
without an active entitlement. Do not hard-code prices into descriptive copy;
the storefront supplies localized prices.

### 6. Required links

End with the Apple Standard EULA and the production Privacy Policy URL after
the v1.0.1 policy is deployed and verified.

## Claims excluded from this draft

Do not add testimonials, customer counts, rankings, revenue or time-saved
claims, cloud sync, route optimization, reminders, accounting integrations,
online payments, team collaboration, or any other feature not present in the
shipping build.

## Review gate

Before using this draft, compare it with the final v1.0.1 binary, localized
store metadata, screenshots, subscription products, and deployed Privacy
Policy. No App Store Connect change is authorized by this document.
