import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Explicit invoicing iPhone replacement", .serialized)
@MainActor
struct SyncInvoicingTakeoverTests {
    @Test
    func replacementAdvancesGenerationAndPullsItsCommitBeforeBecomingDesignated() async throws {
        let f = try fixture()
        try await f.coordinator.takeOverInvoicing()
        let saved = try #require(try f.store.journal())
        #expect(saved.invoicingDeviceID == f.device)
        #expect(saved.invoicingGeneration == 2 && saved.cursor == 1)
        #expect(await f.transport.takeoverCount == 1)
    }

    @Test
    func lostTakeoverReceiptRecoversWithoutAdvancingGenerationAgain() async throws {
        let f = try fixture()
        await f.transport.loseNextReceipt()
        await #expect(throws: URLError.self) { try await f.coordinator.takeOverInvoicing() }
        #expect(try f.store.journal()?.invoicingDeviceID != f.device)
        try await f.coordinator.takeOverInvoicing()
        #expect(try f.store.journal()?.invoicingDeviceID == f.device)
        #expect(try f.store.journal()?.invoicingGeneration == 2)
        #expect(await f.transport.takeoverCount == 1)
    }

    @Test
    func unsavedDraftAndWrongAccountCannotTriggerTakeover() async throws {
        let f = try fixture()
        f.container.mainContext.insert(Client(name: "Open draft"))
        await #expect(throws: SyncGraphError.unsavedChanges) { try await f.coordinator.takeOverInvoicing() }
        #expect(f.container.mainContext.hasChanges)
        #expect(await f.transport.takeoverCount == 0)
        f.container.mainContext.rollback()
        f.coordinator.activate(accountID: UUID())
        await #expect(throws: SyncJournalError.accountMismatch) { try await f.coordinator.takeOverInvoicing() }
        #expect(await f.transport.takeoverCount == 0)
    }

    @Test
    func runtimeRequiresExplicitActionAndStoppedAccountRejectsLateTakeover() async throws {
        let f = try fixture()
        let root = try TemporaryStoreFixtures.makeDirectory(prefix: "Invoicing-Takeover-")
        let runtime = BackupSyncRuntime(container: f.container, transport: f.transport,
            photoTransport: NoInvoicingPhotos(), library: PhotographLibrary(container: f.container,
                fileStore: PhotographFileStore(rootURL: root.appending(path: "HoofPhotographs"))), deviceID: f.device)
        let account = try #require(try f.store.journal()?.accountID)
        try runtime.connect(accountID: account)
        await runtime.waitUntilIdle()
        #expect(!runtime.isInvoicingPhone)
        try #require(runtime.canTakeOverInvoicing)
        #expect(await f.transport.takeoverCount == 0)
        await f.transport.pauseTakeover()
        runtime.requestInvoicingTakeover()
        await f.transport.waitForTakeover()
        #expect(!runtime.canTakeOverInvoicing)
        runtime.stop()
        await f.transport.resumeTakeover()
        await runtime.waitUntilIdle()
        #expect(runtime.state == .localOnly && !runtime.isInvoicingPhone)
        #expect(try f.store.journal()?.invoicingDeviceID != f.device)
        try runtime.connect(accountID: account)
        await runtime.waitUntilIdle()
        #expect(runtime.isInvoicingPhone && !runtime.canTakeOverInvoicing)
    }

    private func fixture() throws -> (container: ModelContainer, store: SyncJournalStore,
                                     coordinator: SyncCoordinator, transport: InvoicingTransport, device: UUID) {
        let container = try ModelContainerFactory.inMemoryTest()
        let transport = InvoicingTransport()
        let device = UUID(), account = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: transport.workspace, deviceID: device)
        let coordinator = SyncCoordinator(container: container, transport: transport, deviceID: device)
        coordinator.activate(accountID: account)
        return (container, store, coordinator, transport, device)
    }
}

private actor InvoicingTransport: SyncTransport {
    nonisolated let workspace = UUID()
    private var designated = UUID()
    private var generation: Int64 = 1
    private var revision: Int64 = 0
    private var lost = false
    private var pause = false
    private var paused: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var takeoverCount = 0
    func bootstrap(deviceID: UUID) async throws -> SyncWorkspaceInfo {
        .init(workspaceID: workspace, deviceID: deviceID, invoicingDeviceID: designated,
              invoicingGeneration: generation, revision: revision)
    }
    func pull(workspaceID: UUID, cursor: Int64) async throws -> SyncPullPage {
        .init(workspaceID: workspaceID, cursor: revision, hasMore: false,
              transactions: cursor < revision ? [.init(workspaceID: workspace, revision: revision, mutations: [])] : [],
              invoicingDeviceID: designated, invoicingGeneration: generation)
    }
    func push(_ batch: SyncBatch) async throws -> SyncPushReceipt { throw SyncTransportError.invalidResponse }
    func takeOverInvoicing(workspaceID: UUID, deviceID: UUID, generation expected: Int64) async throws -> SyncInvoiceTakeoverReceipt {
        #expect(workspaceID == workspace && expected == generation)
        takeoverCount += 1; designated = deviceID; generation += 1; revision += 1
        if pause {
            pause = false
            await withCheckedContinuation { continuation in
                paused = continuation; started?.resume(); started = nil
            }
        }
        if lost { lost = false; throw URLError(.networkConnectionLost) }
        return .init(invoicingDeviceID: designated, invoicingGeneration: generation, revision: revision)
    }
    func loseNextReceipt() { lost = true }
    func pauseTakeover() { pause = true }
    func waitForTakeover() async {
        if paused != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func resumeTakeover() { paused?.resume(); paused = nil }
}

private actor NoInvoicingPhotos: SyncPhotoTransport {
    func manifest(workspaceID: UUID) async throws -> [SyncPhotoManifestEntry] { [] }
    func upload(workspaceID: UUID, payload: SyncPhotoPayload) async throws { throw SyncTransportError.invalidResponse }
    func download(workspaceID: UUID, photoID: UUID) async throws -> Data { throw SyncTransportError.invalidResponse }
    func commit(workspaceID: UUID, payload: SyncPhotoPayload) async throws -> SyncPhotoManifestEntry { throw SyncTransportError.invalidResponse }
    func delete(workspaceID: UUID, photoID: UUID) async throws { throw SyncTransportError.invalidResponse }
}
