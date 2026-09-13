# FarrierFlow Apple Ads Launch Draft

**Status:** Planning only. Do not create, activate, or modify an Apple Ads
campaign from this document.

**Market:** United States

**Research date:** September 13, 2026

## Launch prerequisites

Do not begin meaningful spend until all of the following are true:

- The attribution-enabled FarrierFlow v1.0.1 build is live on the public App
  Store. Simulator, Debug, and TestFlight results are not production
  attribution proof.
- RevenueCat's Apple AdServices integration is configured in **Advanced** mode
  using Sign in with Apple and preferably Read Only Apple Ads API permission.
- Standard AdServices token collection is verified from real Apple Ads traffic.
- RevenueCat can report the acquisition source and, where Apple supplies them,
  campaign, ad group, keyword, and claim type beside subscription outcomes.
- The PostHog custom-event sanity check remains healthy for aggregate onboarding,
  activation, paywall, and subscription-interaction measurement.
- The v1.0.1 Privacy Policy is deployed and its URL verified, and App Store
  Connect App Privacy answers have been reconciled against the final archive.

PostHog and RevenueCat must remain separate: do not send Apple Ads campaign data
or RevenueCat customer identifiers to PostHog, and do not build a cross-provider
identity bridge.

## Intended campaign structure

Prepare the following campaigns, with only the explicitly approved campaigns
enabled for the first test:

```text
US - Competitor - Exact
US - Category - Exact
US - Discovery - Broad
US - Discovery - Search Match
US - Brand - Exact
```

- **Competitor - Exact:** tightly controlled candidate competitor searches.
- **Category - Exact:** high-intent terms describing the product's real jobs.
- **Discovery - Broad:** exploration using broad matches, isolated from exact
  performance.
- **Discovery - Search Match:** Apple's automated query discovery in a separate
  campaign so it cannot obscure exact-term results.
- **Brand - Exact:** protect and measure explicit FarrierFlow demand; keep it
  separate because it reflects existing awareness rather than category demand.

Use negative exact keywords in discovery campaigns for terms already owned by
the exact campaigns. This keeps discovery focused on new search terms and avoids
internal bidding overlap.

## Candidate keywords

Every term below is a **candidate pending actual Apple Ads search-volume, bid,
relevance, and trademark-policy feedback**. These are not performance claims or
authorization to bid on a mark.

### Competitor candidates — exact match only

- `best farrier`
- `farrier fleet`
- `hoofledger`
- `shoein farrier`
- `equinet farrier`

The shortlist reflects currently discoverable US App Store farrier products:
[Best Farrier](https://apps.apple.com/us/app/best-farrier/id1500314269),
[Farrier Fleet](https://apps.apple.com/us/app/farrier-fleet/id6757606700),
[HoofLedger](https://apps.apple.com/us/app/hoofledger-farrier-manager/id6790246458),
[Shoein'](https://apps.apple.com/us/app/shoein-farrier-client-book/id6799500214),
and [EQUINET](https://apps.apple.com/us/app/equinet-mustad-farrier-app/id1459492568).
Recheck availability, spelling, relevance, and Apple's policies immediately
before campaign creation. Do not use competitor names in FarrierFlow App Store
metadata or creative.

### Category candidates — exact match first

- `farrier app`
- `farrier software`
- `farrier scheduling`
- `farrier invoicing`
- `farrier business`
- `farrier management`
- `horse records`
- `hoof records`
- `farrier client management`
- `horse scheduling`

Prioritize terms that describe shipped workflows. Exclude searches for consumer
horse care, veterinary diagnosis, hoof analysis, payment processing, or other
capabilities FarrierFlow does not provide.

## What the $100 promotional credit should test

The first test should answer narrow questions, not attempt to prove long-term
return on ad spend:

1. Does Apple surface meaningful US search volume for exact farrier-workflow
   terms?
2. Which terms produce relevant taps and attributed installs?
3. Do attributed installs reach trial or subscription outcomes in RevenueCat?
4. Does aggregate PostHog data show that onboarding and core activation remain
   healthy while paid traffic is running?

Provisional allocation:

- 50% to `US - Category - Exact`.
- 30% to `US - Competitor - Exact`.
- 20% to `US - Discovery - Search Match`.
- Hold `US - Discovery - Broad` and `US - Brand - Exact` initially unless the
  owner deliberately reallocates after seeing actual volume. Brand can be
  activated separately when measurable brand demand exists; broad discovery
  can follow after negative-keyword coverage is ready.

Use a combined daily cap near $10 to preserve roughly ten days of observation.
Set keyword maximum CPT bids only after reviewing Apple's live bid guidance;
this draft intentionally contains no invented bid amounts. Treat a $100 test as
directional, especially for delayed trials, conversions, and renewals.

## Measurement contract

### Apple Ads

Use Apple Ads for impressions, taps, spend, installs, search terms, and auction
feedback.

### RevenueCat

Use RevenueCat as the acquisition-to-revenue source of truth. Confirm source and,
when supplied by Apple, campaign, ad group, keyword, and claim type alongside
trial, subscription, renewal, and revenue outcomes.

### PostHog

Use PostHog only for aggregate product behavior: onboarding, activation,
paywall, subscription interactions, and core workflow events. PostHog cannot
attribute these behaviors to an Apple Ads keyword in the current privacy model.
Do not attempt user-level reconciliation between the providers.

## Provisional scale, hold, and kill rules

These are conservative review rules for the promotional-credit test, not
promised benchmarks:

- **Hold for more evidence:** fewer than 10 taps for a keyword or fewer than 3
  attributed installs. Do not draw conversion conclusions from smaller samples.
- **Pause for relevance review:** 10 or more taps with no attributed install, or
  clearly irrelevant search terms discovered through Search Match.
- **Pause for downstream review:** 5 or more attributed installs with no
  RevenueCat trial or subscription signal. Check delayed attribution and product
  fit before calling the term ineffective.
- **Consider scaling:** at least 3 attributed paid starts, acceptable onboarding
  and activation health in aggregate PostHog data, and an owner-approved
  customer-acquisition-cost/LTV case. For a conservative initial reference,
  require attributed revenue over the chosen evaluation window to meet or exceed
  spend before increasing the total budget.
- **Stop the test:** attribution fails to reach RevenueCat, a privacy or release
  prerequisite no longer holds, search traffic is consistently irrelevant, or
  the promotional credit is exhausted without enough evidence to justify cash
  spend. “Kill” means pause the campaign and preserve its evidence, not delete
  its history.
- **Do not optimize on renewals prematurely:** renewal and lifetime-value signals
  require time beyond the initial credit test.

The owner should set the final acquisition-cost and payback targets before
spending cash beyond the credit. If RevenueCat attribution is absent or the
privacy/release prerequisites are incomplete, spend remains at zero.

## Launch-time owner actions

After v1.0.1 is public and the release privacy work is complete:

1. Confirm the RevenueCat Advanced Apple AdServices integration is connected to
   the correct Apple Ads account with Read Only permission.
2. Recheck the candidate keywords in Apple Ads for current volume, relevance,
   bid guidance, and policy constraints.
3. Create the five-campaign structure without broadening the app's claims.
4. Activate only the approved first-test campaigns and allocation.
5. Review search terms frequently; add irrelevant queries as negatives.
6. Confirm attribution reaches RevenueCat before increasing spend.
7. Evaluate Apple Ads, RevenueCat, and aggregate PostHog signals at their proper
   boundaries.

No campaign, bid, budget, dashboard integration, or advertising account change
is authorized or performed by this draft.

## Sources

- [Apple Ads campaign structure](https://ads.apple.com/app-store/best-practices/campaign-structure)
- [Apple Ads keyword best practices](https://ads.apple.com/app-store/best-practices/keywords)
- [RevenueCat Apple Ads attribution](https://www.revenuecat.com/docs/integrations/attribution/apple-search-ads)
