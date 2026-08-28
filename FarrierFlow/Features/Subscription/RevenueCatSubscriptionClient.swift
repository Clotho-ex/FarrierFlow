import Foundation
import RevenueCat

nonisolated enum RevenueCatConfigurationError: Error, Equatable {
    case missingPublicSDKKey
}

nonisolated enum RevenueCatConfiguration {
    static let infoKey = "RevenueCatPublicSDKKey"

    static func publicSDKKey(in bundle: Bundle = .main) throws -> String {
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: infoKey) as? String,
            let value = TextNormalization.required(rawValue)
        else {
            throw RevenueCatConfigurationError.missingPublicSDKKey
        }
        return value
    }
}

@MainActor
final class RevenueCatSubscriptionClient: SubscriptionClient, @unchecked Sendable {
    private let purchases: Purchases
    private var packagesByID: [String: Package] = [:]

    init(publicSDKKey: String) {
        purchases = Purchases.configure(withAPIKey: publicSDKKey)
    }

    func customerInfo() async throws -> SubscriptionCustomerSnapshot {
        snapshot(from: try await purchases.customerInfo())
    }

    func offerings() async throws -> [SubscriptionPlan] {
        guard let offering = try await purchases.offerings().current else {
            throw SubscriptionPlanValidationError.invalidOffering
        }
        let packages = offering.availablePackages
        guard packages.count == 2,
              Set(packages.map(\.identifier)).count == packages.count
        else {
            throw SubscriptionPlanValidationError.invalidOffering
        }
        let plans = try packages.map { package in
            guard let kind = SubscriptionProduct.kind(
                for: package.storeProduct.productIdentifier
            ) else {
                throw SubscriptionPlanValidationError.invalidOffering
            }
            switch (kind, package.packageType) {
            case (.monthly, .monthly), (.annual, .annual): break
            default: throw SubscriptionPlanValidationError.invalidOffering
            }
            return SubscriptionPlan(
                id: package.identifier,
                productID: package.storeProduct.productIdentifier,
                kind: kind,
                displayName: package.storeProduct.localizedTitle,
                localizedPrice: package.localizedPriceString,
                subscriptionPeriod: kind == .monthly
                    ? String(localized: "month")
                    : String(localized: "year")
            )
        }
        let validated = try SubscriptionPlanRules.validated(plans)
        packagesByID = Dictionary(uniqueKeysWithValues: packages.map { ($0.identifier, $0) })
        return validated
    }

    func purchase(planID: String) async throws -> SubscriptionPurchaseResult {
        guard let package = packagesByID[planID] else {
            throw SubscriptionPlanValidationError.invalidOffering
        }
        let result = try await purchases.purchase(package: package)
        return SubscriptionPurchaseResult(
            customer: snapshot(from: result.customerInfo),
            wasCancelled: result.userCancelled
        )
    }

    func restorePurchases() async throws -> SubscriptionCustomerSnapshot {
        snapshot(from: try await purchases.restorePurchases())
    }

    func customerInfoUpdates() async -> AsyncStream<SubscriptionCustomerSnapshot> {
        let source = purchases.customerInfoStream
        return AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                for await customerInfo in source {
                    guard let self, !Task.isCancelled else { break }
                    continuation.yield(snapshot(from: customerInfo))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func snapshot(from customerInfo: CustomerInfo) -> SubscriptionCustomerSnapshot {
        SubscriptionCustomerRules.snapshot(
            activeEntitlementIDs: Set(customerInfo.entitlements.active.keys)
        )
    }
}
