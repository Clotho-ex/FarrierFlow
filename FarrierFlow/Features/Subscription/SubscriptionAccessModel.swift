import Observation
import Synchronization

@MainActor
@Observable
final class SubscriptionAccessModel {
    private let client: any SubscriptionClient
    private nonisolated let observationTask = Mutex<Task<Void, Never>?>(nil)
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    private(set) var access: SubscriptionAccess = .loading
    private(set) var plans: [SubscriptionPlan] = []
    private(set) var planLoadState: SubscriptionPlanLoadState = .loading
    private(set) var operation: SubscriptionOperation = .idle
    private(set) var errorMessage: String?

    var allowsMutations: Bool { access.allowsMutations }
    var paywallIsAvailable: Bool {
        planLoadState == .available && plans.count == 2
    }

    init(client: any SubscriptionClient) {
        self.client = client
    }

    func start() {
        guard observationTask.withLock({ $0 == nil }) else { return }
        let client = client
        let task = Task { [weak self, client] in
            let updates = await client.customerInfoUpdates()
            await self?.refresh()
            for await snapshot in updates {
                guard !Task.isCancelled else { return }
                self?.apply(snapshot)
            }
        }
        observationTask.withLock { $0 = task }
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        let verificationFailed: Bool
        do {
            apply(try await client.customerInfo())
            errorMessage = nil
            verificationFailed = false
        } catch {
            if access == .loading { access = .unavailable }
            errorMessage = "FarrierFlow couldn’t verify your subscription. Try again."
            verificationFailed = true
        }
        await reloadOfferings()
        if verificationFailed {
            errorMessage = "FarrierFlow couldn’t verify your subscription. Try again."
        }
    }

    func purchase(
        planID: String,
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) async {
        guard operation == .idle,
              let plan = plans.first(where: { $0.id == planID }) else { return }
        operation = .purchasing(planID: planID)
        defer { operation = .idle }
        let analyticsPlan = plan.kind.analyticsPlan
        analyticsClient.track(.subscriptionPurchaseStarted(analyticsPlan))
        do {
            let result = try await client.purchase(planID: planID)
            guard !result.wasCancelled else {
                errorMessage = nil
                analyticsClient.track(.subscriptionPurchaseCancelled(analyticsPlan))
                return
            }
            apply(result.customer)
            errorMessage = nil
            if result.customer.hasActiveProEntitlement {
                analyticsClient.track(.subscriptionPurchaseCompleted(analyticsPlan))
            }
        } catch {
            errorMessage = "FarrierFlow couldn’t complete the purchase. Try again."
        }
    }

    func restorePurchases(
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) async {
        guard operation == .idle else { return }
        operation = .restoring
        defer { operation = .idle }
        do {
            apply(try await client.restorePurchases())
            errorMessage = nil
            analyticsClient.track(.subscriptionRestoreCompleted)
        } catch {
            errorMessage = "FarrierFlow couldn’t restore purchases. Try again."
        }
    }

    private func reloadOfferings() async {
        planLoadState = .loading
        do {
            plans = try SubscriptionPlanRules.validated(try await client.offerings())
            planLoadState = .available
        } catch {
            plans = []
            planLoadState = .unavailable
            errorMessage = "Subscription plans are unavailable. Try again."
        }
    }

    private func apply(_ snapshot: SubscriptionCustomerSnapshot) {
        access = snapshot.hasActiveProEntitlement ? .pro : .free
    }

    deinit {
        observationTask.withLock { task in
            task?.cancel()
            task = nil
        }
    }
}
