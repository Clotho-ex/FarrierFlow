import Foundation
import SwiftData

nonisolated enum InvoicePaymentError: Error, Equatable {
    case invoiceUnavailable
    case invoiceAlreadyPaid
    case invoiceAlreadyUnpaid
    case totalUnavailable
    case invalidOtherDescription
    case invalidPaymentEvidence
}

@MainActor
enum InvoicePaymentUseCase {
    static func recordPayment(
        invoiceID: PersistentIdentifier,
        method: PaymentMethod,
        receivedAt: Date,
        otherDescription: String? = nil,
        reference: String? = nil,
        note: String? = nil,
        in context: ModelContext
    ) throws {
        do {
            try DomainGraphValidator.validateAll(in: context)
            guard let invoice = try context.existingModel(Invoice.self, for: invoiceID) else {
                throw InvoicePaymentError.invoiceUnavailable
            }
            let total = try InvoiceDomainRules.checkedTotal(
                invoice.invoiceVisits.flatMap(\.lineItems).map(\.amountMinorUnits)
            )
            guard try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                payments: invoice.payments,
                invoiceCurrencyCode: invoice.currencyCode,
                totalMinorUnits: total
            ) == .unpaid else {
                throw InvoicePaymentError.invoiceAlreadyPaid
            }
            let normalizedOther = TextNormalization.optional(otherDescription ?? "")
            guard
                (method == .other && normalizedOther != nil)
                    || (method != .other && normalizedOther == nil)
            else {
                throw InvoicePaymentError.invalidOtherDescription
            }
            let payment = Payment(
                amountMinorUnits: total,
                currencyCode: invoice.currencyCode,
                receivedAt: receivedAt,
                method: method,
                source: .manual,
                otherDescription: normalizedOther,
                reference: TextNormalization.optional(reference ?? ""),
                note: TextNormalization.optional(note ?? ""),
                invoice: invoice
            )
            context.insert(payment)
            try invoice.recordCompletedPayment(payment)
            try DomainGraphValidator.save(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    static func markUnpaid(
        invoiceID: PersistentIdentifier,
        in context: ModelContext
    ) throws {
        do {
            try DomainGraphValidator.validateAll(in: context)
            guard let invoice = try context.existingModel(Invoice.self, for: invoiceID) else {
                throw InvoicePaymentError.invoiceUnavailable
            }
            guard try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                payments: invoice.payments,
                invoiceCurrencyCode: invoice.currencyCode,
                totalMinorUnits: try InvoiceDomainRules.checkedTotal(
                    invoice.invoiceVisits.flatMap(\.lineItems).map(\.amountMinorUnits)
                )
            ) == .paid else {
                throw InvoicePaymentError.invoiceAlreadyUnpaid
            }
            let payment = try invoice.removeCompletedPayment()
            context.delete(payment)
            try DomainGraphValidator.save(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
