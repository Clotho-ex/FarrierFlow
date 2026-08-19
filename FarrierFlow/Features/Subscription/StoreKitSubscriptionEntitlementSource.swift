import StoreKit

nonisolated struct StoreKitSubscriptionEntitlementSource: SubscriptionEntitlementSource {
    func hasCurrentEntitlement(productIDs: Set<String>) async -> Bool {
        if #available(iOS 18.4, *) {
            for productID in productIDs {
                for await result in Transaction.currentEntitlements(for: productID) {
                    if case .verified(let transaction) = result,
                       productIDs.contains(transaction.productID) {
                        return true
                    }
                }
            }
            return false
        }

        return await hasCurrentEntitlementBeforeIOS184(productIDs: productIDs)
    }

    func updates(productIDs: Set<String>) async -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard case .verified(let transaction) = result,
                          productIDs.contains(transaction.productID)
                    else {
                        continue
                    }

                    continuation.yield()
                    await transaction.finish()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

@available(iOS, introduced: 18.0, obsoleted: 18.4)
private func hasCurrentEntitlementBeforeIOS184(productIDs: Set<String>) async -> Bool {
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result,
           productIDs.contains(transaction.productID) {
            return true
        }
    }
    return false
}
