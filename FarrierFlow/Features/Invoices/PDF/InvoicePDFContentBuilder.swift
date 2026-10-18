import Foundation
import SwiftData

nonisolated enum InvoicePDFContentBuilderError: Error, Equatable {
    case invoiceUnavailable
    case totalUnavailable
}

@MainActor
enum InvoicePDFContentBuilder {
    static func build(
        invoiceID: PersistentIdentifier,
        in context: ModelContext
    ) throws -> InvoicePDFContent {
        guard let invoice = try context.existingModel(Invoice.self, for: invoiceID) else {
            throw InvoicePDFContentBuilderError.invoiceUnavailable
        }
        return try build(invoice: invoice)
    }

    static func build(invoice: Invoice) throws -> InvoicePDFContent {
        let total: Int64
        do {
            total = try InvoiceDomainRules.checkedTotal(
                lineItems: invoice.invoiceVisits.flatMap(\.lineItems),
                currencyCode: invoice.currencyCode
            )
        } catch is CheckedMoneyTotalError {
            throw InvoicePDFContentBuilderError.totalUnavailable
        }
        let visits = InvoiceDomainRules.orderedVisits(invoice.invoiceVisits, locale: .current).map { visit in
            InvoicePDFContent.VisitGroup(
                date: visit.visitDateSnapshot,
                location: visit.serviceLocationNameSnapshot,
                address: visit.serviceLocationAddressSnapshot,
                lineItems: InvoiceDomainRules.orderedLineItems(visit.lineItems, locale: .current).map { line in
                    InvoicePDFContent.LineItem(
                        horseName: line.horseNameSnapshot,
                        serviceName: line.serviceNameSnapshot,
                        amountMinorUnits: line.amountMinorUnits
                    )
                }
            )
        }
        let status = try InvoiceDomainRules.validatedStatus(
            rawValue: invoice.statusRawValue,
            payments: invoice.payments,
            invoiceCurrencyCode: invoice.currencyCode,
            totalMinorUnits: total
        )
        let payment = try invoice.payments.first.map { payment in
            guard let method = payment.method else {
                throw InvoiceDomainRuleError.invalidStatus
            }
            return InvoicePDFContent.PaymentContent(
                amountMinorUnits: payment.amountMinorUnits,
                receivedAt: payment.receivedAt,
                method: method,
                otherDescription: payment.otherDescription,
                reference: payment.reference
            )
        }
        return InvoicePDFContent(
            number: try InvoiceDomainRules.formattedNumber(invoice.number),
            invoiceDate: invoice.invoiceDate,
            dueDate: invoice.dueDate,
            status: status,
            payment: payment,
            currencyCode: invoice.currencyCode,
            businessName: invoice.businessNameSnapshot,
            businessPhone: invoice.businessPhoneSnapshot,
            businessEmail: invoice.businessEmailSnapshot,
            businessAddress: invoice.businessAddressSnapshot,
            clientName: invoice.clientNameSnapshot,
            clientPhone: invoice.clientPhoneSnapshot,
            clientEmail: invoice.clientEmailSnapshot,
            visits: visits,
            totalMinorUnits: total,
            note: invoice.note
        )
    }
}
