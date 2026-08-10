import Testing
@testable import FarrierFlow

@Suite("Subscription access model", .serialized)
@MainActor
struct SubscriptionAccessModelTests {
    @Test
    func verifiedCurrentEntitlementGrantsFullAccess() async {
        let source = TestSubscriptionEntitlementSource(
            entitledProductIDs: [SubscriptionProduct.monthly]
        )
        let model = SubscriptionAccessModel(source: source)

        await model.refresh()

        #expect(model.access == .full)
        #expect(model.allowsMutations)
    }

    @Test
    func missingEntitlementIsReadOnly() async {
        let source = TestSubscriptionEntitlementSource()
        let model = SubscriptionAccessModel(source: source)

        await model.refresh()

        #expect(model.access == .readOnly)
        #expect(!model.allowsMutations)
    }

    @Test
    func unrelatedProductIdentifiersNeverGrantAccess() async {
        let source = TestSubscriptionEntitlementSource(
            entitledProductIDs: ["com.farrierflow.unrelated"]
        )
        let model = SubscriptionAccessModel(source: source)

        await model.refresh()

        #expect(model.access == .readOnly)
    }

    @Test
    func startCreatesOnlyOneListener() async {
        let source = TestSubscriptionEntitlementSource(
            entitledProductIDs: [SubscriptionProduct.yearly]
        )
        let model = SubscriptionAccessModel(source: source)

        model.start()
        model.start()

        await eventually {
            await source.listenerCount == 1 && model.access == .full
        }

        #expect(await source.entitlementRequestCount == 1)
    }

    @Test
    func updateRefreshesFullAccessToReadOnly() async {
        let source = TestSubscriptionEntitlementSource(
            entitledProductIDs: [SubscriptionProduct.monthly]
        )
        let model = SubscriptionAccessModel(source: source)
        model.start()

        await eventually {
            await source.listenerCount == 1 && model.access == .full
        }
        await source.setEntitledProductIDs([])
        await source.emitUpdate()

        await eventually { model.access == .readOnly }
        #expect(!model.allowsMutations)
    }

    @Test
    func updateRefreshesReadOnlyAccessToFull() async {
        let source = TestSubscriptionEntitlementSource()
        let model = SubscriptionAccessModel(source: source)
        model.start()

        await eventually {
            await source.listenerCount == 1 && model.access == .readOnly
        }
        await source.setEntitledProductIDs([SubscriptionProduct.yearly])
        await source.emitUpdate()

        await eventually { model.access == .full }
        #expect(model.allowsMutations)
    }

    @Test
    func releasingModelCancelsItsListener() async {
        let source = TestSubscriptionEntitlementSource()
        var model: SubscriptionAccessModel? = SubscriptionAccessModel(source: source)
        weak var releasedModel = model

        model?.start()
        await eventually { await source.listenerCount == 1 }
        model = nil

        await eventually {
            let listenerEnded = await source.listenerEnded
            return releasedModel == nil && listenerEnded
        }
        #expect(releasedModel == nil)
    }

    private func eventually(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0..<100 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        Issue.record("Condition was not met")
    }
}

private actor TestSubscriptionEntitlementSource: SubscriptionEntitlementSource {
    private var entitledProductIDs: Set<String>
    private var continuation: AsyncStream<Void>.Continuation?

    private(set) var entitlementRequestCount = 0
    private(set) var listenerCount = 0
    private(set) var listenerEnded = false

    init(entitledProductIDs: Set<String> = []) {
        self.entitledProductIDs = entitledProductIDs
    }

    func hasCurrentEntitlement(productIDs: Set<String>) async -> Bool {
        entitlementRequestCount += 1
        return !entitledProductIDs.intersection(productIDs).isEmpty
    }

    func updates(productIDs: Set<String>) async -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.continuation = continuation
        listenerCount += 1
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.recordListenerEnded()
            }
        }
        return stream
    }

    func setEntitledProductIDs(_ productIDs: Set<String>) {
        entitledProductIDs = productIDs
    }

    func emitUpdate() {
        continuation?.yield()
    }

    private func recordListenerEnded() {
        listenerEnded = true
    }
}
