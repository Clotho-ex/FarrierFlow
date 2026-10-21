import SwiftData

@MainActor
enum InvoiceDeletionUseCase {
    static func delete(
        invoiceID: PersistentIdentifier,
        in context: ModelContext
    ) throws {
        try RecordDeletionPlan.execute(.invoice(invoiceID), in: context)
    }
}
