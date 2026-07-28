actor PhotographStorageCoordinator {
    private var operationIsActive = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func withExclusiveOperation<Result: Sendable>(
        _ operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        await acquire()
        do {
            let result = try await operation()
            release()
            return result
        } catch {
            release()
            throw error
        }
    }

    private func acquire() async {
        if !operationIsActive {
            operationIsActive = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            operationIsActive = false
            return
        }
        waiters.removeFirst().resume()
    }
}
