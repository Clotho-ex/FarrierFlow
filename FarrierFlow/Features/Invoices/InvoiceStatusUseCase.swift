import Foundation
import SwiftData

nonisolated enum InvoiceStatusError: Error, Equatable {
    case invoiceUnavailable
    case invoiceAlreadyPaid
}

@MainActor
enum InvoiceStatusUseCase {
    static func markPaid(
        invoiceID: PersistentIdentifier,
        paidAt: Date,
        in context: ModelContext
    ) throws {
        do {
            try DomainGraphValidator.validateAll(in: context)
            guard let invoice = try context.existingModel(Invoice.self, for: invoiceID) else {
                throw InvoiceStatusError.invoiceUnavailable
            }
            guard try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                paidAt: invoice.paidAt
            ) == .unpaid else {
                throw InvoiceStatusError.invoiceAlreadyPaid
            }
            invoice.statusRawValue = InvoiceStatus.paid.rawValue
            invoice.paidAt = paidAt
            try DomainGraphValidator.save(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
