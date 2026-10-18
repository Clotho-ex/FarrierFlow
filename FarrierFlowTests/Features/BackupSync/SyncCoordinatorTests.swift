import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Account fenced sync coordination", .serialized)
@MainActor
struct SyncCoordinatorTests {
    @Test
    func upgradeGateSettlesExactPendingBeforeRefusingNewPullOrCommit() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        container.mainContext.insert(Client(name: "Pending"))
        try container.mainContext.save()
        let transport = CoordinatorTransport(), account = UUID(), device = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: transport.workspaceID, deviceID: device)
        let pending = try #require(try store.stage())
        await transport.setMinimumProtocol(3)
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: device)
        coordinator.activate(accountID: account)
        await #expect(throws: SyncTransportError.updateRequired(3)) { try await coordinator.sync() }
        #expect(await transport.sentBatches() == [pending])
        #expect(await transport.pullCount == 0)
        #expect(try store.journal()?.pending == nil && store.journal()?.lastSuccessfulSync == nil)
    }

    @Test
    func confirmedBillingRejectionRetainsExactOperationAndRequiresReviewBeforeResend() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        container.mainContext.insert(Client(name: "Pending"))
        try container.mainContext.save()
        let transport = CoordinatorTransport(), account = UUID(), device = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: transport.workspaceID, deviceID: device)
        let pending = try #require(try store.stage())
        await transport.setBillingRejection()
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: device)
        coordinator.activate(accountID: account)
        await #expect(throws: SyncJournalError.unresolvedConflicts) { try await coordinator.sync() }
        #expect(try store.journal()?.confirmedRejection?.batch == pending)
        await #expect(throws: SyncJournalError.unresolvedConflicts) { try await coordinator.sync() }
        #expect(await transport.sentBatches() == [pending])
        #expect(try store.journal()?.pending == pending)
    }
    @Test
    func committedClientUploadsAndOwnCommitAdvancesCursor() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        container.mainContext.insert(Client(name: "Pat"))
        try container.mainContext.save()
        let transport = CoordinatorTransport()
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: UUID())
        coordinator.activate(accountID: UUID())
        try await coordinator.sync()
        let savedJournal = try SyncJournalStore(container: container).journal()
        let journal = try #require(savedJournal)
        #expect(journal.cursor == 1)
        #expect(journal.pending == nil)
        #expect(journal.baseline.count == 1)
        #expect(journal.lastSuccessfulSync != nil)
        #expect(await transport.sentBatches().count == 1)
    }

    @Test
    func failedUploadKeepsExactOperationForRetry() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        container.mainContext.insert(Client(name: "Pat"))
        try container.mainContext.save()
        let transport = CoordinatorTransport()
        await transport.setOffline(true)
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: UUID())
        coordinator.activate(accountID: UUID())
        await #expect(throws: URLError.self) { try await coordinator.sync() }
        let failedJournal = try SyncJournalStore(container: container).journal()
        let failed = try #require(failedJournal?.pending)
        await transport.setOffline(false)
        try await coordinator.sync()
        let requests = await transport.sentBatches()
        #expect(requests.count == 2)
        #expect(requests.first == failed)
        #expect(requests.last == failed)
        #expect(try SyncJournalStore(container: container).journal()?.pending == nil)
    }

    @Test
    func editCommittedWhileUploadAwaitsIsSentAsANewOperation() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Before")
        container.mainContext.insert(client)
        try container.mainContext.save()
        let transport = CoordinatorTransport()
        await transport.pauseNextPush()
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: UUID())
        coordinator.activate(accountID: UUID())
        let task = Task { try await coordinator.sync() }
        await transport.waitForPausedPush()
        client.name = "After"
        try container.mainContext.save()
        await transport.resumePush()
        try await task.value
        let requests = await transport.sentBatches()
        #expect(requests.count == 2)
        #expect(requests.first?.operationID != requests.last?.operationID)
        #expect(requests.last?.mutations.first?.expectedRevision == 1)
        #expect(requests.last?.mutations.first?.record?.fields["name"] == .string("After"))
        #expect(try SyncJournalStore(container: container).journal()?.cursor == 2)
    }

    @Test
    func signOutRejectsLateReceiptAndRetainsLocalBusinessAndPendingOperation() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        container.mainContext.insert(Client(name: "Keep locally"))
        try container.mainContext.save()
        let transport = CoordinatorTransport()
        await transport.pauseNextPush()
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: UUID())
        coordinator.activate(accountID: UUID())
        let task = Task { try await coordinator.sync() }
        await transport.waitForPausedPush()
        coordinator.deactivate()
        await transport.resumePush()
        await #expect(throws: CancellationError.self) { try await task.value }
        let savedJournal = try SyncJournalStore(container: container).journal()
        let journal = try #require(savedJournal)
        #expect(journal.pending != nil)
        #expect(journal.baseline.isEmpty)
        #expect(journal.lastSuccessfulSync == nil)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Client>()) == 1)
    }

    @Test
    func differentAppleAccountCannotStartACloudRequestForBoundLocalData() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let transport = CoordinatorTransport()
        try SyncJournalStore(container: container).bind(
            accountID: UUID(), workspaceID: transport.workspaceID, deviceID: UUID()
        )
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: UUID())
        coordinator.activate(accountID: UUID())
        await #expect(throws: SyncJournalError.accountMismatch) { try await coordinator.sync() }
        #expect(await transport.bootstrapCount == 0)
        #expect(await transport.sentBatches().isEmpty)
    }

    @Test
    func explicitlyRejectedStaleOperationRefetchesAndMergesDisjointEdits() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Pat")
        container.mainContext.insert(client)
        try container.mainContext.save()
        let record = try #require(SyncGraphCodec.capture(in: ModelContext(container)).first)
        let transport = CoordinatorTransport()
        let account = UUID()
        let device = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: transport.workspaceID, deviceID: device)
        let initial = SyncRemoteTransaction(workspaceID: transport.workspaceID, revision: 1,
            mutations: [.init(id: record.id, kind: record.kind, expectedRevision: 0, record: record)])
        try store.receive(initial)
        client.notes = "Local note"
        try container.mainContext.save()
        let stale = try store.stage()
        var fields = record.fields
        fields["name"] = .string("Cloud name")
        let remote = SyncRecord(id: record.id, kind: record.kind, fields: fields)
        let changed = SyncRemoteTransaction(workspaceID: transport.workspaceID, revision: 2,
            mutations: [.init(id: record.id, kind: record.kind, expectedRevision: 1, record: remote)])
        await transport.setCommits([initial, changed])
        await transport.rejectNextPush()
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: device)
        coordinator.activate(accountID: account)
        try await coordinator.sync()
        let requests = await transport.sentBatches()
        #expect(requests.count == 2)
        #expect(requests.first == stale)
        #expect(requests.last?.operationID != stale?.operationID)
        #expect(requests.last?.mutations.first?.expectedRevision == 2)
        let restored = try #require(ModelContext(container).fetch(FetchDescriptor<Client>()).first)
        #expect(restored.name == "Cloud name")
        #expect(restored.notes == "Local note")
        #expect(client.name == "Cloud name")
        #expect(try store.journal()?.cursor == 3)
    }

    @Test
    func twoIndependentBusinessProfilesRequireReviewWithoutReplacingEither() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        _ = ModelFixtures.makeBusinessProfile(in: container.mainContext)
        try container.mainContext.save()
        let before = try SyncGraphCodec.capture(in: ModelContext(container))
        let other = try ModelContainerFactory.inMemoryTest()
        _ = ModelFixtures.makeBusinessProfile(in: other.mainContext)
        try other.mainContext.save()
        let cloudRecords = try SyncGraphCodec.capture(in: ModelContext(other))
        let transport = CoordinatorTransport()
        let transaction = SyncRemoteTransaction(workspaceID: transport.workspaceID, revision: 1,
            mutations: cloudRecords.map { .init(id: $0.id, kind: $0.kind, expectedRevision: 0, record: $0) })
        await transport.setCommits([transaction])
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: UUID())
        coordinator.activate(accountID: UUID())
        await #expect(throws: SyncJournalError.unresolvedConflicts) { try await coordinator.sync() }
        #expect(try SyncGraphCodec.capture(in: ModelContext(container)) == before)
        let savedJournal = try SyncJournalStore(container: container).journal()
        let journal = try #require(savedJournal)
        #expect(journal.cursor == 0)
        #expect(journal.deferredRemote == transaction)
        #expect(await transport.sentBatches().isEmpty)
    }
}

private actor CoordinatorTransport: SyncTransport {
    let workspaceID = UUID()
    private(set) var bootstrapCount = 0
    private(set) var pullCount = 0
    private var minimumProtocol: Int?
    private var billingRejection = false
    private var batches: [SyncBatch] = []
    private var commits: [SyncRemoteTransaction] = []
    private var offline = false
    private var reject = false
    private var pause = false
    private var paused: CheckedContinuation<Void, Never>?
    private var startedWaiter: CheckedContinuation<Void, Never>?

    func bootstrap(deviceID: UUID) async throws -> SyncWorkspaceInfo {
        bootstrapCount += 1
        return .init(workspaceID: workspaceID, deviceID: deviceID, invoicingDeviceID: deviceID,
                     invoicingGeneration: 1, revision: Int64(commits.count), minimumProtocolVersion: minimumProtocol)
    }
    func push(_ batch: SyncBatch) async throws -> SyncPushReceipt {
        batches.append(batch)
        if billingRejection { throw SyncTransportError.confirmedRejection(.alreadyBilled) }
        if offline { throw URLError(.notConnectedToInternet) }
        if reject { reject = false; throw SyncTransportError.revisionConflict }
        if pause {
            pause = false
            await withCheckedContinuation { continuation in
                paused = continuation
                startedWaiter?.resume()
                startedWaiter = nil
            }
        }
        let revision = Int64(commits.count + 1)
        commits.append(.init(workspaceID: workspaceID, revision: revision, mutations: batch.mutations))
        return .init(operationID: batch.operationID, revision: revision)
    }
    func pull(workspaceID: UUID, cursor: Int64) async throws -> SyncPullPage {
        pullCount += 1
        let transactions = Array(commits.filter { $0.revision > cursor }.prefix(50))
        let nextCursor = transactions.last?.revision ?? cursor
        return .init(workspaceID: workspaceID, cursor: nextCursor,
                     hasMore: nextCursor < commits.count, transactions: transactions,
                     invoicingDeviceID: nil, invoicingGeneration: 1)
    }
    func setOffline(_ value: Bool) { offline = value }
    func setMinimumProtocol(_ value: Int) { minimumProtocol = value }
    func setBillingRejection() { billingRejection = true }
    func setCommits(_ value: [SyncRemoteTransaction]) { commits = value }
    func rejectNextPush() { reject = true }
    func pauseNextPush() { pause = true }
    func waitForPausedPush() async {
        if paused != nil { return }
        await withCheckedContinuation { startedWaiter = $0 }
    }
    func resumePush() { paused?.resume(); paused = nil }
    func sentBatches() -> [SyncBatch] { batches }
}
