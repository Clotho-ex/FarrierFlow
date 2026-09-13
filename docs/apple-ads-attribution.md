# Apple Ads Attribution

FarrierFlow uses RevenueCat's Apple AdServices integration to connect Apple Ads
acquisition context with anonymous subscription and revenue outcomes. RevenueCat
owns this integration. Feature code, business models, and PostHog do not receive
Apple Ads attribution values.

## App-side configuration

After a valid RevenueCat public SDK key has configured `Purchases`, the
RevenueCat subscription provider calls:

```swift
purchases.attribution.enableAdServicesAttributionTokenCollection()
```

This enables **Standard** AdServices attribution. RevenueCat obtains and
submits the token asynchronously. FarrierFlow does not fetch, decode, store,
parse, or retry an attribution token itself. Missing RevenueCat configuration
continues to select `UnavailableSubscriptionClient`; attribution never creates
a separate launch, purchase, restore, entitlement, or user-facing failure path.

FarrierFlow does not request App Tracking Transparency permission and does not
access IDFA. It does not import AppTrackingTransparency or AdSupport, call
`collectDeviceIdentifiers()`, create a custom install identifier, or link
PostHog and RevenueCat identities. Standard attribution is intentionally used;
Detailed attribution is not enabled.

RevenueCat already owns its anonymous App User ID. Its SDK also handles the
AdServices token and delivery bookkeeping in its own cache. FarrierFlow does
not expose or copy those values into business records or analytics events.

## Apple Ads and attribution modes

The advertising account and attribution data level are separate choices:

| Concern | FarrierFlow choice |
| --- | --- |
| Apple Ads account | Advanced |
| RevenueCat Apple AdServices integration | Advanced |
| On-device AdServices attribution | Standard |
| ATT prompt | None |

Advanced Apple Ads supports campaign management capabilities such as keyword
control and bidding. Standard attribution is the privacy-preserving on-device
data level that does not require ATT authorization.

## Owner-side RevenueCat setup

Before the attribution-enabled release receives Apple Ads traffic, the owner
must configure the FarrierFlow RevenueCat project:

1. Open **Integrations -> Apple AdServices** and add the integration.
2. Select **Advanced**.
3. Use **Sign in with Apple** to authorize RevenueCat to the intended Apple Ads
   account.
4. Grant **Read Only** Apple Ads API access. RevenueCat documents this as
   sufficient and recommended for the Advanced integration.

No dashboard action is performed by application code.

RevenueCat reporting can segment attributed outcomes by attribution source,
campaign, ad group, keyword, and claim type when Apple supplies those fields.
FarrierFlow does not promise Detailed-only fields.

## Verification limits

Simulator testing cannot establish real Apple Ads attribution. Debug and
TestFlight traffic can contain placeholder or `Unspecified` attribution fields
and is not proof that a production campaign is working. End-to-end verification
must use an attribution-enabled public App Store build and real Apple Ads
traffic; RevenueCat advises allowing up to seven days to gather attribution
data before drawing conclusions.

Automated tests therefore verify the application integration boundary and
initialization order, not a live campaign response.

## Privacy and release follow-up

This integration sends Apple-provided acquisition attribution to RevenueCat so
subscription, renewal, and revenue results can be analyzed. It does not send
client, horse, visit, invoice, photograph, note, contact, address, payment, or
other FarrierFlow business-record contents. No Apple campaign, ad-group,
keyword, claim, or token value is sent to PostHog.

The checked-in app privacy manifest remains non-tracking and needs no new
required-reason API declaration for this app-owned code. RevenueCat's bundled
privacy manifest continues to describe its own UserDefaults access and purchase
history collection. Apple nevertheless requires App Store Connect App Privacy
answers to include data collected by third-party SDKs, so the owner must review
the archived v1.0.1 privacy report and actual RevenueCat configuration before
updating the questionnaire. Do not infer exact questionnaire selections from
the privacy manifest alone.

Before v1.0.1 ships, the owner should also update FarrierFlow's public Privacy
Policy to disclose that an Apple-provided attribution token and anonymous
RevenueCat customer context are processed for acquisition and subscription
measurement, while clarifying that FarrierFlow does not use IDFA, request ATT,
perform cross-app tracking, or send business-record contents for attribution.
The website and App Store Connect are not changed by this unit.

## References

- [RevenueCat: Apple Ads attribution](https://www.revenuecat.com/docs/integrations/attribution/apple-search-ads)
- [RevenueCat: Apple Ads attribution data reference](https://www.revenuecat.com/docs/integrations/attribution/reference/apple-search-ads)
- [Apple: AdServices](https://developer.apple.com/documentation/adservices)
- [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
