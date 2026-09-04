import Foundation
import Testing
@testable import FarrierFlow

@Suite("Subscription products")
@MainActor
struct SubscriptionProductTests {
    @Test
    func productConstantsMatchApprovedContract() {
        #expect(SubscriptionProduct.proEntitlement == "pro")
        #expect(
            SubscriptionProduct.identifiers == [
                "com.farrierflow.yusufcan.FarrierFlow.pro.monthly",
                "com.farrierflow.yusufcan.FarrierFlow.pro.yearly",
            ]
        )
        #expect(
            SubscriptionProduct.orderedIdentifiers == [
                "com.farrierflow.yusufcan.FarrierFlow.pro.yearly",
                "com.farrierflow.yusufcan.FarrierFlow.pro.monthly",
            ]
        )
    }

    @Test(arguments: [
        (SubscriptionTrial(duration: 1, unit: .day), "1 day free"),
        (SubscriptionTrial(duration: 14, unit: .day), "14 days free"),
        (SubscriptionTrial(duration: 2, unit: .week), "2 weeks free"),
        (SubscriptionTrial(duration: 1, unit: .month), "1 month free"),
        (SubscriptionTrial(duration: 1, unit: .year), "1 year free"),
    ])
    func trialDescriptionUsesProjectedDuration(
        trial: SubscriptionTrial,
        expected: String
    ) {
        #expect(String(localized: trial.localizedCallout) == expected)
    }

    @Test
    func annualSavingsUsesAuthoritativeNumericPrices() {
        let monthly = SubscriptionPlan(
            id: "monthly",
            productID: SubscriptionProduct.monthly,
            kind: .monthly,
            displayName: "Monthly",
            localizedPrice: "$14.99",
            price: Decimal(string: "14.99")!,
            currencyCode: "USD",
            subscriptionPeriod: "month"
        )
        let annual = SubscriptionPlan(
            id: "annual",
            productID: SubscriptionProduct.yearly,
            kind: .annual,
            displayName: "Yearly",
            localizedPrice: "$119.99",
            price: Decimal(string: "119.99")!,
            currencyCode: "USD",
            subscriptionPeriod: "year"
        )

        #expect(
            SubscriptionSavingsRules.annualSavingsPercentage(
                monthly: monthly,
                annual: annual
            ) == 33
        )
    }

    @Test
    func annualSavingsRequiresComparableCurrencyAndPositiveSavings() {
        let monthly = SubscriptionPlan(
            id: "monthly",
            productID: SubscriptionProduct.monthly,
            kind: .monthly,
            displayName: "Monthly",
            localizedPrice: "$10.00",
            price: 10,
            currencyCode: "USD",
            subscriptionPeriod: "month"
        )
        let differentCurrencyAnnual = SubscriptionPlan(
            id: "annual",
            productID: SubscriptionProduct.yearly,
            kind: .annual,
            displayName: "Yearly",
            localizedPrice: "€80.00",
            price: 80,
            currencyCode: "EUR",
            subscriptionPeriod: "year"
        )
        let noSavingsAnnual = SubscriptionPlan(
            id: "annual-expensive",
            productID: SubscriptionProduct.yearly,
            kind: .annual,
            displayName: "Yearly",
            localizedPrice: "$120.00",
            price: 120,
            currencyCode: "USD",
            subscriptionPeriod: "year"
        )

        #expect(
            SubscriptionSavingsRules.annualSavingsPercentage(
                monthly: monthly,
                annual: differentCurrencyAnnual
            ) == nil
        )
        #expect(
            SubscriptionSavingsRules.annualSavingsPercentage(
                monthly: monthly,
                annual: noSavingsAnnual
            ) == nil
        )
    }

    @Test
    func onboardingPurchaseUsesOnlyASelectedAvailablePlan() {
        let monthly = SubscriptionPlan(
            id: "monthly",
            productID: SubscriptionProduct.monthly,
            kind: .monthly,
            displayName: "Monthly",
            localizedPrice: "$14.99",
            subscriptionPeriod: "month"
        )

        #expect(
            OnboardingSubscriptionDecisionRules.purchasePlanID(
                selectedPlanID: monthly.id,
                availablePlans: [monthly]
            ) == monthly.id
        )
    }

    @Test
    func onboardingPurchaseCannotFallBackToReadOnlyWithoutAValidSelection() {
        let monthly = SubscriptionPlan(
            id: "monthly",
            productID: SubscriptionProduct.monthly,
            kind: .monthly,
            displayName: "Monthly",
            localizedPrice: "$14.99",
            subscriptionPeriod: "month"
        )

        #expect(
            OnboardingSubscriptionDecisionRules.purchasePlanID(
                selectedPlanID: nil,
                availablePlans: [monthly]
            ) == nil
        )
        #expect(
            OnboardingSubscriptionDecisionRules.purchasePlanID(
                selectedPlanID: "stale-plan",
                availablePlans: [monthly]
            ) == nil
        )
    }

    @Test
    func eligibleTrialDrivesExplicitPurchaseCopy() {
        let annual = SubscriptionPlan(
            id: "annual",
            productID: SubscriptionProduct.yearly,
            kind: .annual,
            displayName: "Yearly",
            localizedPrice: "$119.99",
            subscriptionPeriod: "year",
            introductoryTrial: .init(duration: 2, unit: .week)
        )

        #expect(
            String(localized: SubscriptionPurchaseCopy.actionTitle(for: annual))
                == "Start 2-Week Free Trial"
        )
        #expect(
            String(localized: SubscriptionPurchaseCopy.disclosure(for: annual))
                == "2 weeks free, then $119.99/year. Cancel anytime."
        )
    }

    @Test
    func ineligiblePlanUsesSubscribeAndAccurateRenewalCopy() {
        let monthly = SubscriptionPlan(
            id: "monthly",
            productID: SubscriptionProduct.monthly,
            kind: .monthly,
            displayName: "Monthly",
            localizedPrice: "$14.99",
            subscriptionPeriod: "month"
        )

        #expect(
            String(localized: SubscriptionPurchaseCopy.actionTitle(for: monthly))
                == "Subscribe"
        )
        #expect(
            String(localized: SubscriptionPurchaseCopy.disclosure(for: monthly))
                == "$14.99/month. Renews automatically. Cancel anytime."
        )
    }

    @Test
    func storeKitConfigurationMatchesApprovedProductContract() throws {
        let configurationURL = sourceRootURL
            .appending(path: "FarrierFlow/Resources/FarrierFlow.storekit")

        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            Issue.record("Expected checked-in StoreKit configuration at \(configurationURL.path())")
            return
        }

        let configurationData = try Data(contentsOf: configurationURL)
        let configuration = try #require(
            JSONSerialization.jsonObject(with: configurationData) as? [String: Any]
        )
        let subscriptionGroups = try #require(
            configuration["subscriptionGroups"] as? [[String: Any]]
        )
        #expect(subscriptionGroups.count == 1)
        let group = try #require(subscriptionGroups.first)

        #expect(group["name"] as? String == "FarrierFlow Pro")
        #expect(
            localizedDisplayName(in: group["localizations"] as? [[String: Any]])
                == "FarrierFlow Pro"
        )

        let products = try #require(group["subscriptions"] as? [[String: Any]])
        #expect(products.count == 2)
        assertProduct(
            try #require(products.first(where: { $0["productID"] as? String == SubscriptionProduct.monthly })),
            identifier: SubscriptionProduct.monthly,
            referenceName: "FarrierFlow Monthly",
            duration: "P1M",
            price: "14.99"
        )
        assertProduct(
            try #require(products.first(where: { $0["productID"] as? String == SubscriptionProduct.yearly })),
            identifier: SubscriptionProduct.yearly,
            referenceName: "FarrierFlow Yearly",
            duration: "P1Y",
            price: "119.99"
        )
    }

    private var sourceRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertProduct(
        _ product: [String: Any],
        identifier: String,
        referenceName: String,
        duration: String,
        price: String
    ) {
        #expect(product["productID"] as? String == identifier)
        #expect(product["referenceName"] as? String == referenceName)
        #expect(product["recurringSubscriptionPeriod"] as? String == duration)
        #expect(product["displayPrice"] as? String == price)
        #expect(product["familyShareable"] as? Bool == false)
        #expect(
            localizedDisplayName(in: product["localizations"] as? [[String: Any]])
                == referenceName
        )

        let introductoryOffer = try? #require(product["introductoryOffer"] as? [String: Any])
        #expect(introductoryOffer?["paymentMode"] as? String == "free")
        #expect(introductoryOffer?["subscriptionPeriod"] as? String == "P2W")
        let introductoryOffers = try? #require(
            product["introductoryOffers"] as? [[String: Any]]
        )
        #expect(introductoryOffers?.count == 1)
        #expect((product["adHocOffers"] as? [[String: Any]])?.isEmpty == true)
        #expect((product["codeOffers"] as? [[String: Any]])?.isEmpty == true)
        #expect((product["winbackOffers"] as? [[String: Any]])?.isEmpty == true)
    }

    private func localizedDisplayName(in localizations: [[String: Any]]?) -> String? {
        localizations?.first?["displayName"] as? String
    }
}
