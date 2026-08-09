import SwiftData

@MainActor
enum VisitDiscardUseCase {
    static func discard(
        visitID: PersistentIdentifier,
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator
    ) throws {
        try coordinator.withMutation {
            guard let visit = try context.existingModel(Visit.self, for: visitID) else {
                throw VisitSaveError.visitUnavailable
            }
            try RecordDeletionRules.delete(visit, in: context)
        }
    }
}
