# FarrierFlow App Store Metadata Source

**Status:** Local source for owner review. See the submission checklist for
dated portal evidence; this file does not by itself prove current App Store
Connect state.

## Product identity

- Name: `FarrierFlow`
- Subtitle: `Farrier records and visits`
- Primary category: `Business`
- Secondary category: Not proposed.
- Age rating: Expected calculated result `4+` (`FOUR_PLUS`). This is a local
  questionnaire source, not a completed App Store Connect declaration. The
  field terminology and API attributes follow [Apple’s current age-rating
  definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
  and the [App Store Connect age-rating
  API](https://developer.apple.com/documentation/appstoreconnectapi/age-ratings).

  | Apple questionnaire field | API attribute | FarrierFlow answer |
  | --- | --- | --- |
  | Parental Controls | `parentalControls` | No (`false`) |
  | Age Assurance | `ageAssurance` | No (`false`) |
  | Unrestricted Web Access | `unrestrictedWebAccess` | No (`false`) |
  | User-Generated Content | `userGeneratedContent` | No (`false`) |
  | Messaging and Chat | `messagingAndChat` | No (`false`) |
  | Advertising | `advertising` | No (`false`) |
  | Social Media | `socialMedia` | No (`false`) |
  | Social Media Disabled/Restricted for Users Under 13 | `socialMediaAgeRestricted` | No (`false`) |
  | Profanity or Crude Humor | `profanityOrCrudeHumor` | None (`NONE`) |
  | Horror/Fear Themes | `horrorOrFearThemes` | None (`NONE`) |
  | Alcohol, Tobacco, or Drug Use or References | `alcoholTobaccoOrDrugUseOrReferences` | None (`NONE`) |
  | Medical or Treatment Information | `medicalOrTreatmentInformation` | None (`NONE`) |
  | Health or Wellness Topics | `healthOrWellnessTopics` | None (`NONE`) |
  | Mature or Suggestive Themes | `matureOrSuggestiveThemes` | None (`NONE`) |
  | Sexual Content or Nudity | `sexualContentOrNudity` | None (`NONE`) |
  | Graphic Sexual Content and Nudity | `sexualContentGraphicAndNudity` | None (`NONE`) |
  | Cartoon or Fantasy Violence | `violenceCartoonOrFantasy` | None (`NONE`) |
  | Realistic Violence | `violenceRealistic` | None (`NONE`) |
  | Prolonged Graphic or Sadistic Realistic Violence | `violenceRealisticProlongedGraphicOrSadistic` | None (`NONE`) |
  | Guns or Other Weapons | `gunsOrOtherWeapons` | None (`NONE`) |
  | Gambling | `gambling` | No (`false`) |
  | Simulated Gambling | `gamblingSimulated` | None (`NONE`) |
  | Contests | `contests` | None (`NONE`) |
  | Loot Boxes | `lootBox` | No (`false`) |
  | Made for Kids | `kidsAgeBand` | No / Not Applicable (`null`; omit) |
  | Age Rating Override | `ageRatingOverride`, `ageRatingOverrideV2`, `koreaAgeRatingOverride` | Not Applicable (`null`; omit) |
  | Optional Age-Suitability URL | `developerAgeRatingInfoUrl` | Omit |

  FarrierFlow records farrier business information and hoof photographs. It has
  no medical advice, treatment content, or age-restricted content. Reconfirm
  this source against the final binary before entering it in App Store Connect.

## Description

FarrierFlow helps independent farriers keep every job connected—from the next
appointment to completed work, invoices, payments, and the next visit.

FARRIERFLOW PRO — SUBSCRIPTION REQUIRED

Creating and editing business records requires a separate purchase of a
monthly or yearly FarrierFlow Pro auto-renewable subscription.

With an active FarrierFlow Pro subscription, you can:

• Keep clients, horses, and service locations organized
• Schedule appointments and see what’s coming next
• Run single- or multi-horse visits from the field
• Record services and work completed for each horse
• Capture hoof photographs as part of the visit record
• Create invoices from completed work
• Record payments by date and method
• Review complete horse and visit history
• Plan the next appointment while the work is still fresh

BUILT FOR FIELD WORK

FarrierFlow is designed to stay fast, clear, and useful while you’re
working—not just when you’re back at a desk.

Your business records are local-first, and no FarrierFlow account or sign-in is
required. If you no longer have an active subscription, your existing records,
photographs, history, and invoice PDFs remain available in read-only mode.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://farrierflow.vercel.app/privacy/

## Promotional text

FarrierFlow Pro subscription: appointments, visits, hoof photos, invoices,
payments, and next appointments—connected on iPhone.

## Keywords

`farrier,horse,hoof,appointment,visit,invoice,client,barn`

## Subscription disclosure

- Product group: `FarrierFlow Pro`
- Monthly product: `com.farrierflow.yusufcan.FarrierFlow.pro.monthly` — US
  price `$14.99/month`
- Yearly product: `com.farrierflow.yusufcan.FarrierFlow.pro.yearly` — US
  price `$119.99/year`
- Introductory offer: `14-day free trial`, subject to Apple's
  subscription-group eligibility rules.
- Billing grace period: `16 days`, enabled for All Renewals in production and
  sandbox during Unit 5; see `docs/release/storekit-configuration.md`.
- Subscription terms: [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)

## App Privacy source

RevenueCat requires **Purchases > Purchase History** with purposes **App
Functionality** and **Analytics**. Select **not linked to identity** and **not
used for tracking** because FarrierFlow configures anonymous RevenueCat App User
IDs and supplies no identifying customer attributes or advertising integration.
Reconfirm against the final binary and implementation before submission. The
FarrierFlow manifest retains Disk Space required-reason `E174.1`.

## Review notes source

FarrierFlow is a local-first iPhone business app and does not require a
FarrierFlow account or sign-in.

FarrierFlow Pro is offered through two auto-renewable subscriptions submitted
together with version 1.0:

• FarrierFlow Monthly — $14.99/month
• FarrierFlow Yearly — $119.99/year

Eligible customers receive the configured 14-day introductory free trial.
Creating and editing business records requires an active FarrierFlow Pro
entitlement. Without an active entitlement, existing records, photographs,
history, and existing invoice PDFs remain available in read-only mode.

On a new installation, enter any business name and continue through the short
workflow introduction to reach the FarrierFlow Pro subscription screen. It
shows both subscription titles, durations, localized prices, renewal terms,
Restore Purchases, and functional Terms of Use and Privacy Policy links.

Terms of Use (Apple Standard EULA):
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Privacy Policy: https://farrierflow.vercel.app/privacy/

No login credentials or local StoreKit configuration are required for review.

## Required public links

- Privacy Policy: `https://farrierflow.vercel.app/privacy/` — RevenueCat
  disclosure published and verified on 2026-08-28.
- Support: `https://farrierflow.vercel.app/support/` — reconfirm the published
  monitored contact before submission.

## Screenshot shot list

Capture only from the final shipping candidate, with no private customer or
account data, debug labels, or test-data disclaimers:

1. Subscription welcome with the localized product choices.
2. Today with a representative non-private workflow state.
3. Schedule or appointment editing with actual shipped controls.
4. Horse history or hoof photographs using deterministic non-customer data.
5. Invoice history or existing Invoice PDF workflow using deterministic
   non-customer data.
6. Read-only state showing records remain available and the reason for the
   restricted controls.

## Superseded 6.3-inch screenshot assets

The following repository assets were captured on 2026-08-20 from an earlier
iOS 26.5 iPhone 17 Pro simulator build. They are retained as historical
evidence only and are not the final 1.0 release-candidate storefront set:

1. `screenshots/6.3-inch/01-subscription-welcome.jpg`
2. `screenshots/6.3-inch/02-today-run-sheet.jpg`
3. `screenshots/6.3-inch/03-schedule.jpg`
4. `screenshots/6.3-inch/04-horse-history.jpg`
5. `screenshots/6.3-inch/05-invoice-detail.jpg`
6. `screenshots/6.3-inch/06-read-only-records.jpg`

Each historical asset is a 1206 x 2622 RGB JPEG with no alpha channel. Do not
upload this set as the 1.0 release candidate.

## Primary 6.9-inch release-candidate assets

The 1.0 release candidate uses six current 1320 x 2868 RGB JPEGs with no alpha
channel under `screenshots/6.9-inch/`. Repository presence proves only local
capture and validation; the submission checklist separately records whether
App Store Connect contains that exact set. A new 6.3-inch set is required only
if the live portal does not inherit the primary 6.9-inch set.

1. `screenshots/6.9-inch/01-farrierflow-pro.jpg`
2. `screenshots/6.9-inch/02-today-run-sheet.jpg`
3. `screenshots/6.9-inch/03-schedule-appointment.jpg`
4. `screenshots/6.9-inch/04-horse-history.jpg`
5. `screenshots/6.9-inch/05-invoice-detail.jpg`
6. `screenshots/6.9-inch/06-read-only-retained-records.jpg`

The set was captured on 2026-09-05 from deterministic fictional DEBUG-only
fixtures on the iPhone 17 Pro Max iOS 26.5 simulator, then visually reviewed
against the compiled Release appearance. It contains no customer, Apple ID, or
testing-label data.
