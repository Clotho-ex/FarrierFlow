import Observation
import Synchronization

@MainActor
@Observable
final class SubscriptionAccessModel {
    private let source: any SubscriptionEntitlementSource
    private nonisolated let observationTask = Mutex<Task<Void, Never>?>(nil)

    private(set) var access: SubscriptionAccess = .loading

    var allowsMutations: Bool {
        access.allowsMutations
    }

    init(source: any SubscriptionEntitlementSource) {
        self.source = source
    }

    func start() {
        guard observationTask.withLock({ $0 == nil }) else {
            return
        }

        let source = source
        let task = Task { [weak self, source] in
            await self?.refresh()

            let updates = await source.updates(
                productIDs: SubscriptionProduct.identifiers
            )
            for await _ in updates {
                guard !Task.isCancelled else {
                    return
                }
                await self?.refresh()
            }
        }
        observationTask.withLock { $0 = task }
    }

    func refresh() async {
        let hasEntitlement = await source.hasCurrentEntitlement(
            productIDs: SubscriptionProduct.identifiers
        )
        access = hasEntitlement ? .full : .readOnly
    }

    deinit {
        observationTask.withLock { task in
            task?.cancel()
            task = nil
        }
    }
}
