import Foundation
import Observation

nonisolated enum PersistenceMutationCoordinatorError: Error, Equatable {
    case writerActive
    case sourceChanged
}

@MainActor
@Observable
final class PersistenceMutationCoordinator {
    nonisolated struct ReadGeneration: Equatable, Sendable {
        fileprivate let token: UUID
    }

    private var token = UUID()
    private var activeWriterCount = 0

    func beginRead() throws -> ReadGeneration {
        guard activeWriterCount == 0 else {
            throw PersistenceMutationCoordinatorError.writerActive
        }
        return ReadGeneration(token: token)
    }

    func validate(_ generation: ReadGeneration) throws {
        guard activeWriterCount == 0 else {
            throw PersistenceMutationCoordinatorError.writerActive
        }
        guard generation.token == token else {
            throw PersistenceMutationCoordinatorError.sourceChanged
        }
    }

    func withMutation<Value>(_ body: () throws -> Value) rethrows -> Value {
        beginMutation()
        defer { endMutation() }
        return try body()
    }

    func withMutation<Value>(_ body: () async throws -> Value) async rethrows -> Value {
        beginMutation()
        defer { endMutation() }
        return try await body()
    }

    private func beginMutation() {
        activeWriterCount += 1
        token = UUID()
    }

    private func endMutation() {
        activeWriterCount -= 1
        token = UUID()
    }
}
