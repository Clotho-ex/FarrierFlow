import Testing
@testable import FarrierFlow

@Suite("Subscription access model", .serialized)
@MainActor
struct SubscriptionAccessModelTests {
    @Test func activeProEntitlementGrantsProAccess() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: true))
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        #expect(model.access == .pro)
        #expect(model.allowsMutations)
    }

    @Test func unrelatedEntitlementDoesNotGrantPro() {
        #expect(!SubscriptionCustomerRules.snapshot(activeEntitlementIDs: ["other"]).hasActiveProEntitlement)
        #expect(SubscriptionCustomerRules.snapshot(activeEntitlementIDs: ["other", "pro"]).hasActiveProEntitlement)
    }

    @Test func confirmedInactiveEntitlementGrantsFreeAccess() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        #expect(model.access == .free)
        #expect(!model.allowsMutations)
    }

    @Test func initialCustomerFailureIsUnavailableAndReadOnly() async {
        let client = TestSubscriptionClient(customerError: TestError.failed)
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        #expect(model.access == .unavailable)
        #expect(!model.allowsMutations)
        #expect(model.errorMessage != nil)
    }

    @Test func refreshFailureRetainsLastConfirmedProAccess() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: true))
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        await client.setCustomerError(TestError.failed)
        await model.refresh()
        #expect(model.access == .pro)
        #expect(model.errorMessage != nil)
    }

    @Test func validOfferingLoadsAnnualThenMonthly() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        await client.setPlans([Self.monthly, Self.annual])
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        #expect(model.plans.map(\.kind) == [.annual, .monthly])
        #expect(model.paywallIsAvailable)
    }

    @Test func missingOrDuplicatePlanMakesPaywallUnavailable() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        await client.setPlans([Self.monthly, Self.monthly])
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        #expect(model.plans.isEmpty)
        #expect(!model.paywallIsAvailable)
        #expect(model.errorMessage != nil)
    }

    @Test func successfulPurchaseUsesReturnedCustomerInfo() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        await client.setPlans([Self.monthly, Self.annual])
        await client.setPurchaseResult(.init(customer: .init(hasActiveProEntitlement: true), wasCancelled: false))
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        await model.purchase(planID: Self.monthly.id)
        #expect(model.access == .pro)
        #expect(model.operation == .idle)
        #expect(model.errorMessage == nil)
        #expect(await client.purchasedPlanIDs == [Self.monthly.id])
    }

    @Test func cancelledPurchaseReturnsToIdleWithoutError() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        await client.setPlans([Self.monthly, Self.annual])
        await client.setPurchaseResult(.init(customer: .init(hasActiveProEntitlement: false), wasCancelled: true))
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        await model.purchase(planID: Self.annual.id)
        #expect(model.access == .free)
        #expect(model.operation == .idle)
        #expect(model.errorMessage == nil)
    }

    @Test func purchaseFailureRetainsConfirmedAccessAndShowsError() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        client.setPlans([Self.monthly, Self.annual])
        client.setPurchaseError(TestError.failed)
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()

        await model.purchase(planID: Self.monthly.id)

        #expect(model.access == .free)
        #expect(model.operation == .idle)
        #expect(model.errorMessage != nil)
    }

    @Test func restoreGrantsProOnlyFromReturnedCustomerInfo() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        await client.setRestoreCustomer(.init(hasActiveProEntitlement: true))
        let model = SubscriptionAccessModel(client: client)
        await model.refresh()
        await model.restorePurchases()
        #expect(model.access == .pro)
        #expect(model.operation == .idle)
    }

    @Test func startCreatesOneListenerAndAppliesUpdatesWithoutRefetch() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: false))
        let model = SubscriptionAccessModel(client: client)
        model.start()
        model.start()
        await eventually { await client.listenerCount == 1 && model.access == .free }
        await client.emit(.init(hasActiveProEntitlement: true))
        await eventually { model.access == .pro }
        #expect(await client.customerRequestCount == 1)
    }

    @Test func updateStreamAppliesExpiration() async {
        let client = TestSubscriptionClient(customer: .init(hasActiveProEntitlement: true))
        let model = SubscriptionAccessModel(client: client)
        model.start()
        await eventually { model.access == .pro }
        client.emit(.init(hasActiveProEntitlement: false))
        await eventually { model.access == .free }
        #expect(!model.allowsMutations)
    }

    private static let monthly = SubscriptionPlan(id: "monthly-package", productID: SubscriptionProduct.monthly, kind: .monthly, displayName: "Monthly", localizedPrice: "$14.99", subscriptionPeriod: "month")
    private static let annual = SubscriptionPlan(id: "annual-package", productID: SubscriptionProduct.yearly, kind: .annual, displayName: "Annual", localizedPrice: "$119.99", subscriptionPeriod: "year")

    private func eventually(_ condition: @escaping @MainActor () async -> Bool) async {
        for _ in 0..<200 {
            if await condition() { return }
            await Task.yield()
        }
        Issue.record("Condition was not met")
    }
}

private enum TestError: Error { case failed }

@MainActor
private final class TestSubscriptionClient: SubscriptionClient, @unchecked Sendable {
    private var customer: SubscriptionCustomerSnapshot
    private var customerError: Error?
    private var offeredPlans: [SubscriptionPlan] = []
    private var purchaseResult = SubscriptionPurchaseResult(customer: .init(hasActiveProEntitlement: false), wasCancelled: false)
    private var purchaseError: Error?
    private var restoreCustomer = SubscriptionCustomerSnapshot(hasActiveProEntitlement: false)
    private var continuation: AsyncStream<SubscriptionCustomerSnapshot>.Continuation?
    private(set) var customerRequestCount = 0
    private(set) var listenerCount = 0
    private(set) var purchasedPlanIDs: [String] = []

    init(customer: SubscriptionCustomerSnapshot = .init(hasActiveProEntitlement: false), customerError: Error? = nil) {
        self.customer = customer
        self.customerError = customerError
    }

    func customerInfo() async throws -> SubscriptionCustomerSnapshot {
        customerRequestCount += 1
        if let customerError { throw customerError }
        return customer
    }
    func offerings() async throws -> [SubscriptionPlan] { offeredPlans }
    func purchase(planID: String) async throws -> SubscriptionPurchaseResult {
        purchasedPlanIDs.append(planID)
        if let purchaseError { throw purchaseError }
        return purchaseResult
    }
    func restorePurchases() async throws -> SubscriptionCustomerSnapshot { restoreCustomer }
    func customerInfoUpdates() async -> AsyncStream<SubscriptionCustomerSnapshot> {
        let (stream, continuation) = AsyncStream<SubscriptionCustomerSnapshot>.makeStream()
        self.continuation = continuation
        listenerCount += 1
        return stream
    }
    func setCustomerError(_ error: Error?) { customerError = error }
    func setPlans(_ plans: [SubscriptionPlan]) { offeredPlans = plans }
    func setPurchaseResult(_ result: SubscriptionPurchaseResult) { purchaseResult = result }
    func setPurchaseError(_ error: Error?) { purchaseError = error }
    func setRestoreCustomer(_ customer: SubscriptionCustomerSnapshot) { restoreCustomer = customer }
    func emit(_ customer: SubscriptionCustomerSnapshot) { continuation?.yield(customer) }
}
