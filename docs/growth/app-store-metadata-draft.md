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

**Draft (98 bytes):**

```text
horse,hoof,client,barn,appointment,visit,business,management,shoeing,trim,payment,software,records
```

Rationale:

- Avoids duplicating `farrier`, `scheduling`, and `invoicing` from the name and
  subtitle.
- Removes the overly generic `service` term.
- Adds `software` and `records`, which can combine with indexed title,
  subtitle, and keyword terms into useful concepts such as “farrier software,”
  “farrier records,” “horse records,” “client records,” “farrier business,” and
  “farrier management.”
- Uses singular forms and no spaces after commas to preserve the byte budget.
- Covers the actual appointment → visit → invoice → payment → next-appointment
  workflow and the horse/client/location record structure.
- Uses nearly the full launch budget while keeping every term truthful to
  shipped functionality.

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

**Draft (142 characters):**

> Run your farrier business from the field. Keep appointments, horse history, visits, hoof photos, invoices, payments, and follow-ups connected.

This sells FarrierFlow's key differentiation—one connected farrier workflow—in
outcome-led, current-product language. Promotional text does not affect search
ranking, so do not turn it into another keyword field.

## Description structure

Use this order for the eventual v1.0.1 description. The current v1.0
subscription disclosure and links must remain accurate in the final text.

### 1. First sentence: complete field workflow

> FarrierFlow keeps your whole farrier workday connected—from appointments and horse history to completed work, hoof photos, invoices, payments, and the next visit.

### 2. Field-work outcome

Follow the opening immediately with this positioning paragraph:

> Built for independent farriers working from the field, FarrierFlow keeps the job moving without splitting scheduling, horse records, visit documentation, invoicing, and follow-up across separate tools.

Keep the description centered on the connected workflow. Do not turn the
opening into a generic feature catalogue.

### 3. Connected records

Use concise bullets covering only shipped functionality:

- Organize clients, horses, service locations, and services.
- Schedule appointments and review upcoming work.
- Record single- or multi-horse visits and hoof photographs.
- Create and share invoice PDFs directly from completed work.
- Track paid and unpaid invoices and record how payment was received.
- Schedule the next appointment while the completed visit is still fresh.

### 4. Local-first privacy and continuity

State that core business records stay on the iPhone, no FarrierFlow account is
required, and the app does not upload business-record contents as analytics.
Do not claim that literally no data leaves the device: v1.0.1 uses PostHog,
RevenueCat, and Apple AdServices for the limited analytics, subscription, and
attribution processing disclosed in the Privacy Policy. Do not broaden this
into unsupported security or privacy claims.

### 5. Subscription and read-only access

Retain the truthful FarrierFlow Pro auto-renewal disclosure. State that an
active FarrierFlow Pro subscription is required to create and edit business
records. If a subscription ends, existing records, photographs, history, and
invoice PDFs remain available read-only. Do not hard-code prices into
descriptive copy; the storefront supplies localized prices, subscription
periods, and any introductory trial.

### 6. Required links

End with the Apple Standard EULA and the production Privacy Policy URL after
the v1.0.1 policy is deployed and verified.

## Launch-ready description draft

The following is recommended launch copy. The Privacy Policy URL remains an
explicit placeholder until the v1.0.1 policy is deployed and its production URL
is verified.

> **FarrierFlow keeps your whole farrier workday connected—from appointments and horse history to completed work, hoof photos, invoices, payments, and the next visit.**
>
> Built for independent farriers working from the field, FarrierFlow keeps the job moving without splitting scheduling, horse records, visit documentation, invoicing, and follow-up across separate tools.
>
> **Keep every job connected**
>
> • Organize clients, horses, service locations, and services.
> • Schedule appointments and review upcoming work.
> • Record single- or multi-horse visits and hoof photographs.
> • Create and share invoice PDFs directly from completed work.
> • Track paid and unpaid invoices and record how payment was received.
> • Schedule the next appointment while the completed visit is still fresh.
>
> **Built for the field**
>
> FarrierFlow is designed around the actual sequence of farrier work. See what's next, review the horse's history, record the work while you're there, invoice afterward, and keep the next visit moving.
>
> **Your records stay yours**
>
> Core business records are stored locally on your iPhone. FarrierFlow doesn't require an account or upload the contents of your client, horse, visit, photograph, invoice, or payment records as analytics.
>
> **FarrierFlow Pro**
>
> An active FarrierFlow Pro subscription is required to create and edit business records. If your subscription ends, your existing records, photographs, history, and invoice PDFs remain available read-only.
>
> Subscriptions renew automatically unless canceled through your Apple Account settings. Any introductory trial, subscription period, and price shown during purchase are provided by the App Store.
>
> Terms of Use: Apple Standard EULA
> Privacy Policy: [production privacy-policy URL]

Do not replace `[production privacy-policy URL]` with a guessed or unpublished
URL.

## Claims excluded from this draft

Do not add testimonials, customer counts, rankings, revenue or time-saved
claims, cloud sync, route optimization, reminders, accounting integrations,
online payments, team collaboration, or any other feature not present in the
shipping build.

## Review gate

Before using this draft, compare it with the final v1.0.1 binary, final
screenshots, deployed Privacy Policy, actual subscription products, localized
metadata, final keyword byte count, current Apple policy, and any real Apple
Ads or App Store search-term evidence available by then.

No App Store Connect change is authorized by this document while v1.0 remains
under review.
