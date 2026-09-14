# FarrierFlow Apple Ads Launch Draft

**Status:** Planning only. Do not create, activate, or modify an Apple Ads
campaign from this document.

**Market:** United States

**Research date:** September 14, 2026

## Release context and sequence

FarrierFlow v1.0 is currently under Apple App Review. FarrierFlow v1.0.1 remains
a planned post-v1.0 analytics and attribution release; no v1.0.1 submission has
occurred.

```text
v1.0 currently under Apple App Review
        ↓
v1.0 approved and publicly released
        ↓
prepare and submit v1.0.1
        ↓
v1.0.1 approved and publicly released
        ↓
verify production PostHog events
        ↓
verify production RevenueCat Standard AdServices attribution
        ↓
begin controlled Apple Ads spend
```

When v1.0 becomes publicly available, the owner may establish or verify the
Apple Ads account and promotional-credit eligibility. Do not begin meaningful
spend against v1.0 merely because a credit becomes available. The controlled
acquisition test waits until the attribution-enabled v1.0.1 build is publicly
live.

## Current terminology

Apple's advertising product is now branded **Apple Ads**. RevenueCat's current
documentation and dashboard may still label the connection **Apple Search Ads**
or **Apple AdServices**. In this draft, those RevenueCat labels refer to the
same Apple acquisition-attribution integration; they do not authorize a second
attribution provider.

## Launch prerequisites

Do not begin meaningful spend until all of the following are true:

- v1.0 has completed App Review and is publicly released.
- The attribution-enabled FarrierFlow v1.0.1 build has been submitted, approved,
  and is live on the public App Store. Simulator, Debug, and TestFlight results
  are not production attribution proof.
- Production PostHog custom events are verified.
- RevenueCat Standard AdServices token collection is enabled in the public
  v1.0.1 binary. It requires no App Tracking Transparency prompt.
- RevenueCat's Apple AdServices integration is connected in **Advanced** mode
  using Sign in with Apple and **Read Only** Apple Ads API permission. Read and
  Write access is not required for the planned reporting integration.
- RevenueCat can report acquisition source and, where Apple supplies them,
  campaign, ad group, keyword, and claim type beside subscription outcomes.
- The v1.0.1 Privacy Policy is deployed and its URL verified.
- App Store Connect App Privacy answers are reconciled against the final
  v1.0.1 archive.
- Final App Store metadata and screenshots are approved.
- The Apple Ads Billing page confirms that the promotional credit is eligible,
  applied, and still available.
- Candidate keywords have been freshly checked for current App Store listings,
  search relevance, bid guidance, and policy constraints.
- The owner has approved the cash-spend ceiling beyond any promotional credit.

Do not assume the $100 credit exists. Eligibility depends on the relevant Apple
Ads account, App Store Connect linkage, and an app being available for sale.
Verify the applied credit and remaining balance in Apple Ads Billing before
planning against it.

## Long-term campaign architecture

Keep the following structure prepared:

```text
US - Brand - Exact
US - Category - Exact
US - Competitor - Exact
US - Discovery
    Broad              (ad group; Search Match off)
    Search Match       (ad group; no keywords; Search Match on)
```

- **Brand - Exact:** measures explicit FarrierFlow demand separately from
  new-demand acquisition. Keep it prepared but initially inactive unless
  meaningful brand search demand exists.
- **Category - Exact:** targets high-intent terms describing FarrierFlow's
  shipped professional and business purpose.
- **Competitor - Exact:** tests tightly controlled candidate searches for
  comparable farrier products without implying affiliation.
- **Discovery / Search Match:** prepared, initially inactive. It is the next
  expansion path when exact terms have little volume, exact terms have been
  sufficiently tested, or new search-query discovery is useful.
- **Discovery / Broad:** prepared, initially inactive. Broad exploration comes
  later than Search Match for this small-budget launch plan.

Use the **Manage Bids** strategy for the controlled launch test. Set keyword
maximum cost-per-tap bids only after reviewing Apple's live guidance. Apple Ads
also offers Maximize Conversions, but its recommended conversion volume and
learning period do not fit this initial small, niche promotional-credit test.
This draft contains no invented CPT amounts.

Add the exact-match keywords from Brand, Category, and Competitor as exact
negative keywords in both Discovery ad groups before enabling Discovery. This
keeps discovery focused on new search terms and limits internal overlap.

When entering keywords, explicitly select the intended match type: new positive
keywords default to broad match. Exact match can still include close variants
such as misspellings and reordered words; it does not mean literal-only matching.
Apple Ads does not let an existing keyword's match type be edited, so a mistaken
entry must be paused and added again with the correct match type.

## Candidate keywords

Every term below is a **candidate pending actual Apple Ads search volume,
relevance, bid guidance, and policy feedback**. No volume, cost, or performance
is assumed.

### Category Tier A — initial exact test

```text
[farrier app]
[farrier software]
[farrier scheduling]
[farrier invoicing]
[farrier business]
[farrier management]
```

These terms express relatively direct professional or business intent around
FarrierFlow's shipped purpose.

### Category Tier B — secondary candidates

```text
[farrier client management]
[horse records]
[hoof records]
[horse scheduling]
```

These remain relevant candidates, but they may attract broader equestrian or
consumer intent. Do not let them consume the first controlled test budget before
Tier A is evaluated.

### Competitor Tier A — initial exact test

```text
[best farrier]
[farrier fleet]
[the farriers app]
[hoofledger]
```

### Competitor Tier B — add only if more volume is needed

```text
[fi ontrack]
[forge by catch ride]
[equinet]
[mustad farrier]
[shoein farrier]
```

The candidate set corresponds to farrier-oriented products found during the
research pass, including [Best Farrier](https://apps.apple.com/us/app/best-farrier/id1500314269),
[Farrier Fleet](https://apps.apple.com/us/app/farrier-fleet/id6757606700),
[The Farriers App](https://apps.apple.com/us/app/the-farriers-app/id1587307883),
[HoofLedger](https://apps.apple.com/us/app/hoofledger-farrier-manager/id6790246458),
[FI-ONTRACK](https://apps.apple.com/us/app/fi-ontrack/id6791783977),
[Forge by Catch Ride](https://apps.apple.com/us/app/forge-by-catch-ride/id6786847781),
[EQUINET - Mustad Farrier App](https://apps.apple.com/us/app/equinet-mustad-farrier-app/id1459492568),
and [Shoein'](https://apps.apple.com/us/app/shoein-farrier-client-book/id6799500214).

Reverify each exact App Store listing and name immediately before campaign
creation. Check current search relevance, trademark and policy constraints, and
auction guidance. If a candidate cannot be verified, omit it rather than
guessing. Do not put competitor names in FarrierFlow metadata, screenshots, or
other creative, and do not imply affiliation.

## Initial $100 test

The first test should answer one clear question:

> Can explicit farrier-software and direct-competitor search intent acquire
> relevant users for FarrierFlow?

```text
INITIAL $100 TEST

Category Exact — approximately $60
    [farrier app]
    [farrier software]
    [farrier scheduling]
    [farrier invoicing]
    [farrier business]
    [farrier management]

Competitor Exact — approximately $40
    [best farrier]
    [farrier fleet]
    [the farriers app]
    [hoofledger]

Initially inactive
    US - Brand - Exact
    US - Discovery / Search Match
    US - Discovery / Broad
```

The approximate 60/40 split is an owner-controlled planning allocation, not a
guaranteed Apple account-wide spending cap. The $100 credit is too small to
divide across many intent buckets. Controlled exact-match intent is easier to
interpret; Search Match remains valuable for later discovery, while Brand
demand measures existing awareness rather than new-user discovery.

Apple Ads budgets are configured per campaign; there is no ordinary combined
cross-campaign daily cap. Daily spend may exceed a campaign's daily budget on a
high-opportunity day, while Apple's monthly limit is the daily budget multiplied
by 30.4. Set conservative per-campaign daily budgets and end dates, monitor the
Billing page, and manually pause campaigns before the owner-approved total
exposure is exceeded.

The credit test should answer:

1. Is there meaningful US search volume for explicit professional farrier-app
   terms?
2. Which controlled terms generate relevant taps?
3. Which terms generate attributed installs?
4. Which terms generate RevenueCat trial or subscription signals?
5. Is aggregate FarrierFlow onboarding and activation health still normal while
   paid traffic is running?

The promotional-credit test is directional. It is not sufficient by itself to
prove long-term LTV or scalable acquisition. Do not optimize based on renewals
during the initial credit test.

## Staged activation

### Stage 1 — Category Exact

Activate `US - Category - Exact` and measure whether the Tier A category terms
produce meaningful search volume and relevant taps or attributed installs.

### Stage 2 — Competitor Exact

After Category is configured correctly and production attribution is
functioning, activate `US - Competitor - Exact` with the Tier A competitor
terms.

### Stage 3 — Search Match if needed

Only if exact-match traffic is too limited, exact terms have been sufficiently
tested, or more search-query discovery is useful, activate the `Search Match`
ad group in `US - Discovery`.

Before enabling Search Match, add Category Exact and Competitor Exact terms as
exact negatives. Add Brand Exact terms too if Brand has been configured.

### Stage 4 — Broad Discovery later

Keep the `Broad` Discovery ad group inactive during the initial credit test.
Do not enable Broad merely because the promotional credit exists. Consider it
only after Search Match and the controlled exact campaigns provide enough
evidence to justify broader experimentation.

### Brand

Keep `US - Brand - Exact` prepared but initially inactive unless meaningful
FarrierFlow brand search demand exists.

## Measurement contract

### Apple Ads

Apple Ads answers:

> Which searches and campaigns produce impressions, taps, spend, installs, and
> search-term evidence?

Use Apple Ads for impressions, taps, spend, tap-through and view-through
installs, search terms, and auction feedback.

### RevenueCat

RevenueCat answers:

> Which Apple Ads acquisition cohorts subscribe and generate subscription
> revenue?

Use RevenueCat as the acquisition-to-revenue source of truth. Confirm source and,
when supplied by Apple, campaign, ad group, keyword, and claim type alongside
trial, subscription, renewal, and revenue outcomes.

RevenueCat requests Apple's attribution details after receiving the device's
AdServices token and advises allowing up to seven days for data to gather before
judging a new integration. Debug and TestFlight attribution may appear as
`Unspecified`. Do not treat an immediate blank or unspecified field as final
evidence that production attribution failed.

### PostHog

PostHog answers:

> Is FarrierFlow's overall onboarding and activation funnel healthy while paid
> acquisition is running?

PostHog is a **global product-health guardrail**, not a keyword-level
attribution system. It cannot currently say:

> “Users from [farrier app] completed visits at X%.”

FarrierFlow deliberately does not build a cross-provider user identity bridge.
Do not send Apple Ads campaign data or RevenueCat customer identifiers to
PostHog, attempt user-level provider reconciliation, or weaken the privacy
architecture to gain keyword-level behavioral attribution.

## Decision rules

These are operational review states for a small niche-market test, not
statistical proof or promised benchmarks. Confirm the attribution cohort has had
time to reach RevenueCat and mature before classifying it.

### Hold

Use when there are fewer than 10 taps, fewer than 3 attributed installs, or the
attribution cohort is too immature. Do not draw conversion conclusions.

### Relevance Review

Use when there are at least 10 taps and no attributed install, or search-term
reports show clearly irrelevant intent. Check attribution delay and
configuration before blaming the keyword.

### Downstream Review

Use when there are at least 5 attributed installs but no trial or subscription
signal after an appropriate maturation window. Investigate keyword relevance,
product-page conversion, onboarding or paywall health, and attribution delay.

### Promising

A keyword or campaign may be classified as **Promising** when all of the
following are true:

```text
≥3 attributed paid starts
+
search intent is clearly relevant
+
CAC is within an owner-acceptable provisional range
+
aggregate PostHog funnel health shows no obvious deterioration
```

A Promising result permits a modest follow-up paid test. It does not prove
scalability.

### Scale Candidate

A keyword or campaign becomes a **Scale Candidate** only after stronger evidence:

```text
≥5 attributed paid starts
+
the cohort has matured beyond the introductory-trial boundary
+
CAC remains below the owner-approved acquisition ceiling
+
net proceeds / contribution-value trajectory remains credible
+
performance survives at least one controlled spend increase
```

Five conversions are still not statistically conclusive in a niche market; this
is an operational decision threshold, not scientific proof.

Evaluate net proceeds or contribution value against acquisition spend when
those measures are available. Gross transaction revenue can overstate economics
because it may not reflect Apple's commission, refunds, taxes, churn, or delayed
renewals. During the initial credit test, gross attributed revenue may be used
only as a provisional directional signal when net proceeds are not yet
available. Do not invent a precise margin model before real subscription data
exists.

### Pause / Kill

Pause when relevance remains poor, attribution is broken, a privacy or release
prerequisite fails, controlled follow-up spend confirms poor economics, or the
credit is exhausted and the evidence does not justify cash spend. Preserve the
campaign and its history; do not delete historical evidence merely because a
campaign is paused.

The owner must set the final acquisition-cost and payback targets before
spending cash beyond the credit. If attribution is absent or release/privacy
prerequisites are incomplete, spend remains at zero.

## Launch-time owner actions

After v1.0.1 is publicly live and every review-gate item is satisfied:

1. Confirm the RevenueCat Advanced Apple AdServices integration is connected to
   the correct Apple Ads account with Read Only permission.
2. Confirm promotional-credit eligibility and the actual remaining balance in
   Apple Ads Billing.
3. Recheck candidate keywords for current listings, volume, relevance, bid
   guidance, trademark constraints, and policy requirements.
4. Create the prepared campaign structure without broadening FarrierFlow's
   claims.
5. Select Manage Bids, set conservative per-campaign daily budgets and end dates,
   and activate Stage 1 only.
6. Follow the staged activation plan; do not automatically enable Brand or
   either Discovery ad group.
7. Review search terms and add irrelevant queries as negatives.
8. Allow for RevenueCat's documented attribution delay and confirm production
   attribution before increasing spend.
9. Evaluate Apple Ads, RevenueCat, and global PostHog signals only at their
   defined boundaries.

## Review gate

Before any Apple Ads campaign is activated:

1. v1.0 has completed review.
2. v1.0.1 has been submitted, approved, and is publicly live.
3. PostHog production events are verified.
4. RevenueCat Standard AdServices attribution is enabled in the public binary.
5. RevenueCat Advanced Apple Ads integration is connected.
6. The v1.0.1 Privacy Policy is deployed.
7. App Store Connect App Privacy answers are reconciled.
8. App Store metadata and screenshots are final.
9. Promotional-credit availability is confirmed.
10. Keyword availability, relevance, bid guidance, and policy constraints are
    freshly rechecked.
11. The owner approves the cash-spend ceiling beyond any promotional credit.

No campaign, bid, budget, dashboard integration, or advertising account change
is authorized or performed by this draft.

## Sources

- [Apple Ads campaign structure](https://ads.apple.com/app-store/best-practices/campaign-structure)
- [Apple Ads campaign-structure help](https://ads.apple.com/app-store/help/campaigns/0056-structure-campaigns)
- [Apple Ads keyword match types](https://ads.apple.com/app-store/help/keywords/0059-understand-keyword-match-types)
- [Apple Ads negative keywords](https://ads.apple.com/app-store/help/keywords/0060-use-negative-keywords)
- [Apple Ads search-results bid strategies](https://ads.apple.com/app-store/help/ad-placements/0082-search-results)
- [Apple Ads Maximize Conversions guidance](https://ads.apple.com/app-store/best-practices/maximize-conversions)
- [Apple Ads budget behavior](https://ads.apple.com/app-store/help/bids-and-budget/0016-manage-budgets)
- [Apple Ads promotional-credit eligibility](https://ads.apple.com/app-store/help/billing/0032-apple-ads-promo-credit)
- [RevenueCat Apple Ads attribution](https://www.revenuecat.com/docs/integrations/attribution/apple-search-ads)
