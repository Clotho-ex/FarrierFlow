import Testing
@testable import FarrierFlow

@Suite("Persistence mutation coordinator")
@MainActor
struct PersistenceMutationCoordinatorTests {
    @Test
    func stableReadRemainsValid() throws {
        let coordinator = PersistenceMutationCoordinator()
        let generation = try coordinator.beginRead()

        try coordinator.validate(generation)
    }

    @Test
    func rejectsReadWhileWriterIsActive() async throws {
        let coordinator = PersistenceMutationCoordinator()
        let gate = AsyncTestGate()
        let writer = Task { @MainActor in
            try await coordinator.withMutation {
                await gate.signalStartedAndWait()
            }
        }
        await gate.waitUntilStarted()

        #expect(throws: PersistenceMutationCoordinatorError.writerActive) {
            _ = try coordinator.beginRead()
        }
        await gate.release()
        try await writer.value
    }

    @Test
    func invalidatesReadWhenWriterStartsAndFinishesBetweenChecks() throws {
        let coordinator = PersistenceMutationCoordinator()
        let generation = try coordinator.beginRead()

        coordinator.withMutation {}

        #expect(throws: PersistenceMutationCoordinatorError.sourceChanged) {
            try coordinator.validate(generation)
        }
    }
}

private actor AsyncTestGate {
    private var hasStarted = false
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func signalStartedAndWait() async {
        hasStarted = true
        startedWaiter?.resume()
        startedWaiter = nil

        await withCheckedContinuation { continuation in
            releaseWaiter = continuation
        }
    }

    func waitUntilStarted() async {
        guard !hasStarted else {
            return
        }

        await withCheckedContinuation { continuation in
            startedWaiter = continuation
        }
    }

    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}
