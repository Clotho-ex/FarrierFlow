import SwiftData

@MainActor
enum VisitDiscardUseCase {
    static func discard(
        visitID: PersistentIdentifier,
        in context: ModelContext
    ) throws {
        guard let visit = try context.existingModel(Visit.self, for: visitID) else {
            throw VisitSaveError.visitUnavailable
        }
        try RecordDeletionRules.delete(visit, in: context)
    }
}
