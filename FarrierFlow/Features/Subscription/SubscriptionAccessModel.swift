import Observation
import Synchronization

@MainActor
@Observable
final class SubscriptionAccessModel {
    private let client: any SubscriptionClient
    private nonisolated let observationTask = Mutex<Task<Void, Never>?>(nil)

    private(set) var access: SubscriptionAccess = .loading
    private(set) var plans: [SubscriptionPlan] = []
    private(set) var operation: SubscriptionOperation = .idle
    private(set) var errorMessage: String?

    var allowsMutations: Bool { access.allowsMutations }
    var paywallIsAvailable: Bool { plans.count == 2 }

    init(client: any SubscriptionClient) {
        self.client = client
    }

    func start() {
        guard observationTask.withLock({ $0 == nil }) else { return }
        let client = client
        let task = Task { [weak self, client] in
            await self?.refresh()
            let updates = await client.customerInfoUpdates()
            for await snapshot in updates {
                guard !Task.isCancelled else { return }
                self?.apply(snapshot)
            }
        }
        observationTask.withLock { $0 = task }
    }

    func refresh() async {
        do {
            apply(try await client.customerInfo())
            errorMessage = nil
        } catch {
            if access == .loading { access = .unavailable }
            errorMessage = "FarrierFlow couldn’t verify your subscription. Try again."
        }
        await reloadOfferings()
    }

    func purchase(planID: String) async {
        guard operation == .idle, plans.contains(where: { $0.id == planID }) else { return }
        operation = .purchasing(planID: planID)
        defer { operation = .idle }
        do {
            let result = try await client.purchase(planID: planID)
            guard !result.wasCancelled else {
                errorMessage = nil
                return
            }
            apply(result.customer)
            errorMessage = nil
        } catch {
            errorMessage = "FarrierFlow couldn’t complete the purchase. Try again."
        }
    }

    func restorePurchases() async {
        guard operation == .idle else { return }
        operation = .restoring
        defer { operation = .idle }
        do {
            apply(try await client.restorePurchases())
            errorMessage = nil
        } catch {
            errorMessage = "FarrierFlow couldn’t restore purchases. Try again."
        }
    }

    private func reloadOfferings() async {
        do {
            plans = try SubscriptionPlanRules.validated(try await client.offerings())
        } catch {
            plans = []
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
