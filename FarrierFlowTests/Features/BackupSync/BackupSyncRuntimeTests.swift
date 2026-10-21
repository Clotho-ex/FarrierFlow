import Foundation
import Combine
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Automatic sync lifecycle", .serialized)
@MainActor
struct BackupSyncRuntimeTests {
    @Test
    func temporaryArchiveSavesAreFilteredBeforeSwiftUIBuffersTheirContexts() async throws {
        let f = try makeFixture()
        let (events, continuation) = AsyncStream<Void>.makeStream()
        var received = 0
        let observer = NotificationCenter.default.publisher(for: ModelContext.didSave)
            .filter { f.runtime.acceptsSaveNotification($0) }
            .receive(on: DispatchQueue.main)
            .sink { notification in
                MainActor.assumeIsolated {
                    f.runtime.didSave(notification)
                    received += 1
                    continuation.yield()
                }
            }
        defer { observer.cancel() }
        try autoreleasepool {
            let isolated = try ModelContainerFactory.inMemoryTest()
            isolated.mainContext.insert(Client(name: "Temporary archived graph"))
            try isolated.mainContext.save()
        }
        f.client.notes = "Own store notification"
        try f.container.mainContext.save()
        var iterator = events.makeAsyncIterator()
        _ = await iterator.next()
        #expect(received == 1)
        #expect(try ModelContext(f.container).fetchCount(FetchDescriptor<Client>()) == 1)
    }
    @Test
    func accountFreeLaunchNeverStartsCloudRequests() async throws {
        let fixture = try makeFixture()
        fixture.runtime.requestSync()
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.state == .localOnly)
        #expect(await fixture.transport.bootstrapCount == 0)
        #expect(await fixture.photos.manifestCount == 0)
    }

    @Test
    func connectionAutomaticallyProtectsCommittedRecordsWithoutPurchaseDependency() async throws {
        let fixture = try makeFixture()
        try fixture.runtime.connect(accountID: UUID())
        #expect(fixture.runtime.state != .upToDate)
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.state == .upToDate)
        #expect(fixture.runtime.status?.protectedRecordCount == 1)
        #expect(fixture.runtime.status?.isFullyProtected == true)
        #expect(await fixture.transport.batches.count == 1)
        #expect(await fixture.photos.manifestCount == 1)
    }

    @Test
    func offlineFailureRetainsExactOutboxAndReconnectRetriesIt() async throws {
        let fixture = try makeFixture()
        await fixture.transport.setOffline(true)
        try fixture.runtime.connect(accountID: UUID())
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.state == .waitingForConnection)
        let pending = try #require(try fixture.store.journal()?.pending)
        #expect(fixture.runtime.status?.isFullyProtected == false)
        await fixture.transport.setOffline(false)
        fixture.runtime.requestSync()
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.state == .upToDate)
        #expect(await fixture.transport.batches.last == pending)
    }

    @Test
    func signOutStopsLateUploadBeforePhotoRequestsOrSuccessStatus() async throws {
        let fixture = try makeFixture()
        await fixture.transport.pauseNextPush()
        try fixture.runtime.connect(accountID: UUID())
        await fixture.transport.waitForPausedPush()
        fixture.runtime.stop()
        await fixture.transport.resumePush()
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.state == .localOnly)
        #expect(fixture.runtime.accountID == nil)
        #expect(await fixture.photos.manifestCount == 0)
        #expect(try fixture.store.journal()?.pending != nil)
        #expect(try fixture.store.journal()?.lastSuccessfulSync == nil)
        #expect(try ModelContext(fixture.container).fetchCount(FetchDescriptor<Client>()) == 1)
    }

    @Test
    func savesAndInvalidationsDuringSyncCoalesceWithoutLosingNewerEdit() async throws {
        let fixture = try makeFixture()
        await fixture.transport.pauseNextPush()
        try fixture.runtime.connect(accountID: UUID())
        await fixture.transport.waitForPausedPush()
        fixture.client.name = "Saved while uploading"
        try fixture.container.mainContext.save()
        fixture.runtime.requestSync()
        fixture.runtime.requestSync()
        await fixture.transport.resumePush()
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.state == .upToDate)
        #expect(await fixture.transport.batches.count == 2)
        #expect(try fixture.store.journal()?.baseline.first?.fields["name"] == .string("Saved while uploading"))
    }

    @Test
    func differentAccountCannotStartAnyRequestForBoundRecords() async throws {
        let fixture = try makeFixture()
        try fixture.store.bind(accountID: UUID(), workspaceID: fixture.transport.workspaceID, deviceID: UUID())
        #expect(throws: SyncJournalError.accountMismatch) {
            try fixture.runtime.connect(accountID: UUID())
        }
        await fixture.runtime.waitUntilIdle()
        #expect(await fixture.transport.bootstrapCount == 0)
        #expect(await fixture.photos.manifestCount == 0)
    }

    @Test
    func cancelledGenerationCannotConsumeAReplacementGenerationsSyncRequest() async throws {
        let fixture = try makeFixture()
        try fixture.runtime.connect(accountID: UUID())
        fixture.runtime.stop()
        let account = UUID()
        try fixture.runtime.connect(accountID: account)
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.accountID == account)
        #expect(fixture.runtime.state == .upToDate)
        #expect(await fixture.transport.bootstrapCount == 1)
        #expect(fixture.runtime.status?.isFullyProtected == true)
    }

    @Test
    func committedBusinessSaveTriggersSyncButJournalOnlySavesDoNotLoop() async throws {
        let fixture = try makeFixture()
        try fixture.runtime.connect(accountID: UUID())
        await fixture.runtime.waitUntilIdle()
        let before = await fixture.photos.manifestCount
        let journalID = try #require(try ModelContext(fixture.container)
            .fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()).first?.persistentModelID)
        fixture.runtime.didSave(Notification(name: ModelContext.didSave,
            object: fixture.container.mainContext, userInfo: [
                ModelContext.NotificationKey.updatedIdentifiers.rawValue: [journalID]
            ]))
        await fixture.runtime.waitUntilIdle()
        #expect(await fixture.photos.manifestCount == before)
        fixture.client.name = "Committed automatically"
        try fixture.container.mainContext.save()
        fixture.runtime.didSave(Notification(name: ModelContext.didSave,
            object: fixture.container.mainContext, userInfo: [
                ModelContext.NotificationKey.updatedIdentifiers.rawValue: [fixture.client.persistentModelID]
            ]))
        await fixture.runtime.waitUntilIdle()
        #expect(await fixture.transport.batches.count == 2)
        #expect(fixture.runtime.state == .upToDate)
    }

    @Test
    func anotherStoresSaveCannotTriggerThisAccountsCloudRequests() async throws {
        let fixture = try makeFixture()
        try fixture.runtime.connect(accountID: UUID())
        await fixture.runtime.waitUntilIdle()
        let before = await fixture.photos.manifestCount
        let other = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Unrelated")
        other.mainContext.insert(client)
        try other.mainContext.save()
        fixture.runtime.didSave(Notification(name: ModelContext.didSave,
            object: other.mainContext, userInfo: [
                ModelContext.NotificationKey.insertedIdentifiers.rawValue: [client.persistentModelID]
            ]))
        await fixture.runtime.waitUntilIdle()
        #expect(await fixture.photos.manifestCount == before)
    }

    @Test
    func actualSwiftDataNotificationSchedulesSavedChangesWithoutCheckpointLoops() async throws {
        let fixture = try makeFixture()
        let observation = NotificationCenter.default.publisher(for: ModelContext.didSave)
            .sink { [weak runtime = fixture.runtime] notification in
                MainActor.assumeIsolated { runtime?.didSave(notification) }
            }
        defer { observation.cancel() }
        try fixture.runtime.connect(accountID: UUID())
        await fixture.runtime.waitUntilIdle()
        fixture.client.name = "Actual didSave"
        try fixture.container.mainContext.save()
        await fixture.runtime.waitUntilIdle()
        #expect(await fixture.transport.batches.count == 2)
        #expect(fixture.runtime.state == .upToDate)
        #expect(try fixture.store.journal()?.baseline.first?.fields["name"] == .string("Actual didSave"))
    }

    @Test(arguments: [false, true])
    func localOnlySaveInvalidatesScreensWithoutCapturingProtectionStatus(hasIdentifiers: Bool) async throws {
        let fixture = try makeFixture()
        let version = fixture.runtime.recordsVersion
        fixture.client.name = "Saved locally"
        try fixture.container.mainContext.save()
        fixture.runtime.didSave(Notification(name: ModelContext.didSave, object: fixture.container.mainContext,
            userInfo: hasIdentifiers ? [ModelContext.NotificationKey.updatedIdentifiers.rawValue: [fixture.client.persistentModelID]] : nil))
        #expect(fixture.runtime.recordsVersion != version)
        #expect(fixture.runtime.status == nil)
        #expect(fixture.runtime.state == .localOnly)
        await fixture.runtime.waitUntilIdle()
        #expect(await fixture.transport.bootstrapCount == 0)
        #expect(await fixture.photos.manifestCount == 0)
    }

    @Test
    func editsAfterSignOutRefreshScreensAndUploadOnReconnect() async throws {
        let fixture = try makeFixture()
        let account = UUID()
        try fixture.runtime.connect(accountID: account)
        await fixture.runtime.waitUntilIdle()
        fixture.runtime.stop()
        let version = fixture.runtime.recordsVersion
        fixture.client.name = "Saved after sign-out"
        try fixture.container.mainContext.save()
        fixture.runtime.didSave(Notification(name: ModelContext.didSave, object: fixture.container.mainContext,
            userInfo: [ModelContext.NotificationKey.updatedIdentifiers.rawValue: [fixture.client.persistentModelID]]))
        #expect(fixture.runtime.recordsVersion != version)
        #expect(fixture.runtime.state == .localOnly)
        #expect(await fixture.transport.batches.count == 1)
        try fixture.runtime.connect(accountID: account)
        await fixture.runtime.waitUntilIdle()
        #expect(fixture.runtime.state == .upToDate)
        #expect(try fixture.store.journal()?.baseline.first?.fields["name"] == .string("Saved after sign-out"))
    }

    @Test
    func signedOutJournalCheckpointsDoNotInvalidateScreens() throws {
        let fixture = try makeFixture()
        try fixture.store.bind(accountID: UUID(), workspaceID: fixture.transport.workspaceID, deviceID: UUID())
        let journalID = try #require(try ModelContext(fixture.container)
            .fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()).first?.persistentModelID)
        let version = fixture.runtime.recordsVersion
        fixture.runtime.didSave(Notification(name: ModelContext.didSave, object: fixture.container.mainContext,
            userInfo: [ModelContext.NotificationKey.updatedIdentifiers.rawValue: [journalID]]))
        #expect(fixture.runtime.recordsVersion == version)
        #expect(fixture.runtime.status == nil)
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Pat")
        container.mainContext.insert(client)
        try container.mainContext.save()
        let root = try TemporaryStoreFixtures.makeDirectory(prefix: "Sync-Runtime-")
        let library = PhotographLibrary(container: container,
            fileStore: PhotographFileStore(rootURL: root.appending(path: "HoofPhotographs")))
        let transport = RuntimeRecordTransport()
        let photos = RuntimePhotoTransport(workspaceID: transport.workspaceID)
        return Fixture(container: container, client: client, transport: transport, photos: photos,
            store: SyncJournalStore(container: container),
            runtime: BackupSyncRuntime(container: container, transport: transport,
                photoTransport: photos, library: library, deviceID: UUID()))
    }

    private struct Fixture {
        let container: ModelContainer
        let client: Client
        let transport: RuntimeRecordTransport
        let photos: RuntimePhotoTransport
        let store: SyncJournalStore
        let runtime: BackupSyncRuntime
    }
}

private actor RuntimeRecordTransport: SyncTransport {
    let workspaceID = UUID()
    private(set) var bootstrapCount = 0
    private(set) var batches: [SyncBatch] = []
    private var commits: [SyncRemoteTransaction] = []
    private var offline = false
    private var primaryDevice: UUID?
    private var pause = false
    private var paused: CheckedContinuation<Void, Never>?
    private var startedWaiter: CheckedContinuation<Void, Never>?

    func bootstrap(deviceID: UUID) async throws -> SyncWorkspaceInfo {
        bootstrapCount += 1
        if primaryDevice == nil { primaryDevice = deviceID }
        return .init(workspaceID: workspaceID, deviceID: deviceID, invoicingDeviceID: primaryDevice,
            invoicingGeneration: 1, revision: Int64(commits.count))
    }
    func push(_ batch: SyncBatch) async throws -> SyncPushReceipt {
        batches.append(batch)
        if offline { throw URLError(.notConnectedToInternet) }
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
        let page = Array(commits.filter { $0.revision > cursor }.prefix(50))
        let next = page.last?.revision ?? cursor
        return .init(workspaceID: workspaceID, cursor: next, hasMore: next < commits.count,
            transactions: page, invoicingDeviceID: primaryDevice, invoicingGeneration: 1)
    }
    func setOffline(_ value: Bool) { offline = value }
    func pauseNextPush() { pause = true }
    func waitForPausedPush() async {
        if paused != nil { return }
        await withCheckedContinuation { startedWaiter = $0 }
    }
    func resumePush() { paused?.resume(); paused = nil }
}

private actor RuntimePhotoTransport: SyncPhotoTransport {
    let workspaceID: UUID
    private(set) var manifestCount = 0
    init(workspaceID: UUID) { self.workspaceID = workspaceID }
    func manifest(workspaceID: UUID) async throws -> [SyncPhotoManifestEntry] {
        #expect(workspaceID == self.workspaceID)
        manifestCount += 1
        return []
    }
    func upload(workspaceID: UUID, payload: SyncPhotoPayload) async throws { throw SyncTransportError.invalidResponse }
    func download(workspaceID: UUID, photoID: UUID) async throws -> Data { throw SyncTransportError.invalidResponse }
    func commit(workspaceID: UUID, payload: SyncPhotoPayload) async throws -> SyncPhotoManifestEntry { throw SyncTransportError.invalidResponse }
    func delete(workspaceID: UUID, photoID: UUID) async throws { throw SyncTransportError.invalidResponse }
}
