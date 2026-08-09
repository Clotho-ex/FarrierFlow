import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Photograph storage serialization", .serialized)
@MainActor
struct PhotographConcurrencyTests {
    @Test
    func addRetainsMutationScopeAcrossTheStorageSuspensionPoint() async throws {
        let gate = SuspensionPoint()
        let mutationCoordinator = PersistenceMutationCoordinator()
        let generation = try mutationCoordinator.beginRead()
        let fixture = try makeFixture(
            mutationCoordinator: mutationCoordinator,
            hooks: PhotographOperationHooks(
                afterAddCanonicalMove: {
                    await gate.suspend()
                }
            )
        )

        let addTask = Task {
            try await fixture.library.add(
                sourceData: PhotographTestFixtures.jpeg(),
                to: fixture.graph.visitHorseID
            )
        }
        await gate.waitUntilSuspended()

        #expect(throws: PersistenceMutationCoordinatorError.writerActive) {
            _ = try mutationCoordinator.beginRead()
        }

        gate.resume()
        let id = try await addTask.value
        #expect(FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
        #expect(try fixture.library.items(for: fixture.graph.visitHorseID).map(\.id) == [id])
        #expect(throws: PersistenceMutationCoordinatorError.sourceChanged) {
            try mutationCoordinator.validate(generation)
        }
    }

    @Test
    func reconciliationWaitsUntilAddMetadataSaveCompletes() async throws {
        let gate = SuspensionPoint()
        let events = EventRecorder()
        let fixture = try makeFixture(
            hooks: PhotographOperationHooks(
                afterAddCanonicalMove: {
                    await events.record("add-moved")
                    await gate.suspend()
                },
                beforeReconciliationInspection: {
                    await events.record("reconcile-inspected")
                }
            )
        )

        let addTask = Task {
            let id = try await fixture.library.add(
                sourceData: PhotographTestFixtures.jpeg(),
                to: fixture.graph.visitHorseID
            )
            await events.record("add-finished")
            return id
        }
        await gate.waitUntilSuspended()
        let reconcileTask = Task {
            await events.record("reconcile-requested")
            try await fixture.library.prepareAndReconcile()
        }
        await events.wait(for: "reconcile-requested")
        gate.resume()
        let id = try await addTask.value
        try await reconcileTask.value

        #expect(
            await events.values() == [
                "add-moved",
                "reconcile-requested",
                "add-finished",
                "reconcile-inspected",
            ]
        )
        #expect(FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
    }

    @Test
    func reconciliationWaitsThroughDeleteQuarantineAndSave() async throws {
        let gate = SuspensionPoint()
        let events = EventRecorder()
        let fixture = try makeFixture(
            hooks: PhotographOperationHooks(
                afterDeleteQuarantineMove: {
                    await events.record("delete-quarantined")
                    await gate.suspend()
                },
                beforeReconciliationInspection: {
                    await events.record("reconcile-inspected")
                }
            )
        )
        let id = try await fixture.library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: fixture.graph.visitHorseID
        )

        let deleteTask = Task {
            try await fixture.library.delete(id: id)
            await events.record("delete-finished")
        }
        await gate.waitUntilSuspended()
        let reconcileTask = Task {
            await events.record("reconcile-requested")
            try await fixture.library.prepareAndReconcile()
        }
        await events.wait(for: "reconcile-requested")
        gate.resume()
        try await deleteTask.value
        try await reconcileTask.value

        #expect(
            await events.values() == [
                "delete-quarantined",
                "reconcile-requested",
                "delete-finished",
                "reconcile-inspected",
            ]
        )
    }

    @Test
    func reconciliationWaitsThroughDeleteRollbackAndQuarantineRestore() async throws {
        let gate = SuspensionPoint()
        let events = EventRecorder()
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Delete-Restore-Concurrency-\(UUID().uuidString)-"
        )
        let store = PhotographFileStore(
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory)
        )
        let coordinator = PhotographStorageCoordinator()
        let initialLibrary = PhotographTestFixtures.makeLibrary(
            graph: graph,
            rootURL: store.rootURL,
            coordinator: coordinator
        )
        let id = try await initialLibrary.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: graph.visitHorseID
        )
        let failingLibrary = PhotographTestFixtures.makeLibrary(
            graph: graph,
            rootURL: store.rootURL,
            coordinator: coordinator,
            saving: { _ in throw ForcedConcurrencyFailure.expected },
            hooks: PhotographOperationHooks(
                beforeDeleteQuarantineRestore: {
                    await events.record("delete-restoring")
                    await gate.suspend()
                }
            )
        )
        let reconcilingLibrary = PhotographTestFixtures.makeLibrary(
            graph: graph,
            rootURL: store.rootURL,
            coordinator: coordinator,
            hooks: PhotographOperationHooks(
                beforeReconciliationInspection: {
                    await events.record("reconcile-inspected")
                }
            )
        )

        let deleteTask = Task {
            do {
                try await failingLibrary.delete(id: id)
                Issue.record("Delete unexpectedly succeeded")
            } catch {
                #expect(error as? PhotographLibraryError == .persistenceFailed)
            }
            await events.record("delete-finished")
        }
        await gate.waitUntilSuspended()
        let reconcileTask = Task {
            await events.record("reconcile-requested")
            try await reconcilingLibrary.prepareAndReconcile()
        }
        await events.wait(for: "reconcile-requested")
        gate.resume()
        await deleteTask.value
        try await reconcileTask.value

        #expect(
            await events.values() == [
                "delete-restoring",
                "reconcile-requested",
                "delete-finished",
                "reconcile-inspected",
            ]
        )
        #expect(FileManager.default.fileExists(atPath: store.canonicalURL(for: id).path))
    }

    @Test
    func reconciliationWaitsThroughPhotoAwareVisitDiscard() async throws {
        let gate = SuspensionPoint()
        let events = EventRecorder()
        let fixture = try makeFixture(
            hooks: PhotographOperationHooks(
                afterDiscardQuarantineMoves: {
                    await events.record("discard-quarantined")
                    await gate.suspend()
                },
                beforeReconciliationInspection: {
                    await events.record("reconcile-inspected")
                }
            )
        )
        _ = try await fixture.library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: fixture.graph.visitHorseID
        )

        let discardTask = Task {
            try await fixture.library.discardInProgressVisit(id: fixture.graph.visitID)
            await events.record("discard-finished")
        }
        await gate.waitUntilSuspended()
        let reconcileTask = Task {
            await events.record("reconcile-requested")
            try await fixture.library.prepareAndReconcile()
        }
        await events.wait(for: "reconcile-requested")
        gate.resume()
        try await discardTask.value
        try await reconcileTask.value

        #expect(
            await events.values() == [
                "discard-quarantined",
                "reconcile-requested",
                "discard-finished",
                "reconcile-inspected",
            ]
        )
    }

    @Test
    func twoConcurrentAddsCannotExceedSixteenAvailablePhotographs() async throws {
        let fixture = try makeFixture()
        let data = try PhotographTestFixtures.jpeg(width: 20, height: 20)
        for _ in 0..<15 {
            _ = try await fixture.library.add(
                sourceData: data,
                to: fixture.graph.visitHorseID
            )
        }

        async let first: Result<UUID, Error> = capture {
            try await fixture.library.add(sourceData: data, to: fixture.graph.visitHorseID)
        }
        async let second: Result<UUID, Error> = capture {
            try await fixture.library.add(sourceData: data, to: fixture.graph.visitHorseID)
        }
        let results = await [first, second]

        #expect(results.count { if case .success = $0 { true } else { false } } == 1)
        #expect(
            results.contains {
                guard case .failure(let error) = $0 else { return false }
                return error as? PhotographLibraryError == .photographLimitReached
            }
        )
        #expect(try fixture.library.items(for: fixture.graph.visitHorseID).count == 16)
    }

    @Test
    func serializationReleasesAfterThrownFailure() async throws {
        let fixture = try makeFixture(
            hooks: PhotographOperationHooks(
                afterAddCanonicalMove: { throw ForcedConcurrencyFailure.expected }
            )
        )

        await #expect(throws: ForcedConcurrencyFailure.expected) {
            try await fixture.library.add(
                sourceData: PhotographTestFixtures.jpeg(),
                to: fixture.graph.visitHorseID
            )
        }
        try await fixture.library.prepareAndReconcile()
    }

    private func makeFixture(
        mutationCoordinator: PersistenceMutationCoordinator = PersistenceMutationCoordinator(),
        hooks: PhotographOperationHooks = .production
    ) throws -> ConcurrencyFixture {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Concurrency-\(UUID().uuidString)-"
        )
        let store = PhotographFileStore(
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory)
        )
        return ConcurrencyFixture(
            graph: graph,
            store: store,
            library: PhotographTestFixtures.makeLibrary(
                graph: graph,
                rootURL: store.rootURL,
                mutationCoordinator: mutationCoordinator,
                hooks: hooks
            )
        )
    }

    private func capture(
        _ operation: () async throws -> UUID
    ) async -> Result<UUID, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }
}

@MainActor
private final class SuspensionPoint {
    private var isSuspended = false
    private var suspendedWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    func suspend() async {
        isSuspended = true
        suspendedWaiters.forEach { $0.resume() }
        suspendedWaiters.removeAll()
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
    }

    func waitUntilSuspended() async {
        if isSuspended { return }
        await withCheckedContinuation { continuation in
            suspendedWaiters.append(continuation)
        }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}

private actor EventRecorder {
    private var events: [String] = []
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func record(_ event: String) {
        events.append(event)
        for waiter in waiters.removeValue(forKey: event) ?? [] {
            waiter.resume()
        }
    }

    func wait(for event: String) async {
        if events.contains(event) { return }
        await withCheckedContinuation { continuation in
            waiters[event, default: []].append(continuation)
        }
    }

    func values() -> [String] {
        events
    }
}

private struct ConcurrencyFixture {
    let graph: PhotographTestFixtures.VisitGraph
    let store: PhotographFileStore
    let library: PhotographLibrary
}

private enum ForcedConcurrencyFailure: Error {
    case expected
}
