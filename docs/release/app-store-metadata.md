# FarrierFlow App Store Metadata Source

**Status:** Local source for owner review. Nothing in this file has been
entered in App Store Connect. Public Privacy Policy and Support URLs are
unmet release gates, so this file intentionally contains no invented URL.

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

FarrierFlow is a local-first business app for independent farriers. Keep
clients, horses, service locations, appointments, visits, hoof photographs,
invoices, payment status, and next appointments together on your iPhone.

FarrierFlow Pro is available as an auto-renewable monthly or yearly
subscription. If access is unavailable, existing records, photographs,
history, and existing Invoice PDF generation and sharing stay available in
read-only mode. Manage or restore App Store purchases through the app's native
StoreKit controls.

## Promotional text

Local-first farrier records, appointments, visit history, hoof photographs,
and invoices on iPhone.

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

Proposed App Privacy answer: **Data Not Collected**. Reconfirm against the
final binary, public policy, and App Store Connect questionnaire before
submission. The current manifest declares no tracking, no tracking domains,
and no collected data types; it declares the Disk Space required-reason API
with reason `E174.1`.

## Review notes source

FarrierFlow is local-first and has no FarrierFlow account or developer-operated
server. A verified current App Store entitlement provides full access; without
one, existing records remain readable and ordinary mutations are disabled. No
login or local Xcode StoreKit configuration is required or supplied for App
Review. Submit the monthly and yearly products with version 1.0 so App Review
can evaluate the production App Store purchase and restore path.

## Required public links

- Privacy Policy: **Unmet gate — owner-controlled HTTPS URL not supplied.**
- Support: **Unmet gate — monitored public support contact and HTTPS URL not
  supplied.**

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
