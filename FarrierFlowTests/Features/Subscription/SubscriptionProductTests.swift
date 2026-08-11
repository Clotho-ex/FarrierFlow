import Foundation
import Testing
@testable import FarrierFlow

@Suite("Subscription products")
@MainActor
struct SubscriptionProductTests {
    @Test
    func productConstantsMatchApprovedContract() {
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
