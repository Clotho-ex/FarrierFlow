import SwiftData

nonisolated enum InvoiceDeletionError: Error, Equatable {
    case invoiceUnavailable
    case invoicePaid
}

@MainActor
enum InvoiceDeletionUseCase {
    static func deleteUnpaid(
        invoiceID: PersistentIdentifier,
        in context: ModelContext
    ) throws {
        do {
            try DomainGraphValidator.validateAll(in: context)
            guard let invoice = try context.existingModel(Invoice.self, for: invoiceID) else {
                throw InvoiceDeletionError.invoiceUnavailable
            }
            guard try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                paidAt: invoice.paidAt
            ) == .unpaid else {
                throw InvoiceDeletionError.invoicePaid
            }
            let sourceWorkItems = invoice.invoiceVisits.flatMap(\.lineItems)
                .compactMap(\.sourceWorkItem)
            for workItem in sourceWorkItems {
                workItem.invoiceLineItem = nil
            }
            context.delete(invoice)
            try DomainGraphValidator.save(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
