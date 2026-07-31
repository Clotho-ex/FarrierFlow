import Foundation
import SwiftData

nonisolated enum InvoicePDFContentBuilderError: Error, Equatable { case invoiceUnavailable; case totalUnavailable }

@MainActor
enum InvoicePDFContentBuilder {
    static func build(invoiceID: PersistentIdentifier, in context: ModelContext) throws -> InvoicePDFContent {
        guard let invoice = try context.existingModel(Invoice.self, for: invoiceID) else { throw InvoicePDFContentBuilderError.invoiceUnavailable }
        let status = try InvoiceDomainRules.validatedStatus(rawValue: invoice.statusRawValue, paidAt: invoice.paidAt)
        let visits = InvoiceDomainRules.orderedVisits(invoice.invoiceVisits, locale: .current).map { visit in
            InvoicePDFContent.VisitGroup(date: visit.visitDateSnapshot, location: visit.serviceLocationNameSnapshot, address: visit.serviceLocationAddressSnapshot, lineItems: InvoiceDomainRules.orderedLineItems(visit.lineItems, locale: .current).map { line in
                InvoicePDFContent.LineItem(horseName: line.horseNameSnapshot, serviceName: line.serviceNameSnapshot, amountMinorUnits: line.amountMinorUnits)
            })
        }
        guard let total = try? InvoiceDomainRules.checkedTotal(visits.flatMap(\.lineItems).map(\.amountMinorUnits)) else { throw InvoicePDFContentBuilderError.totalUnavailable }
        return InvoicePDFContent(number: try InvoiceDomainRules.formattedNumber(invoice.number), invoiceDate: invoice.invoiceDate, dueDate: invoice.dueDate, status: status, paidAt: invoice.paidAt, businessName: invoice.businessNameSnapshot, businessPhone: invoice.businessPhoneSnapshot, businessEmail: invoice.businessEmailSnapshot, businessAddress: invoice.businessAddressSnapshot, clientName: invoice.clientNameSnapshot, clientPhone: invoice.clientPhoneSnapshot, clientEmail: invoice.clientEmailSnapshot, visits: visits, totalMinorUnits: total, note: invoice.note)
    }
}
