import Foundation
import SwiftData

@MainActor
enum InvoiceProjection {
    static func summary(from invoice: Invoice, locale: Locale) throws -> InvoiceSummary {
        let status = try InvoiceDomainRules.validatedStatus(
            rawValue: invoice.statusRawValue,
            paidAt: invoice.paidAt
        )
        return InvoiceSummary(
            id: invoice.persistentModelID,
            number: try InvoiceDomainRules.formattedNumber(invoice.number),
            clientName: invoice.clientNameSnapshot,
            invoiceDate: invoice.invoiceDate,
            total: total(for: invoice),
            status: status
        )
    }

    static func detail(from invoice: Invoice, locale: Locale) throws -> InvoiceDetail {
        let status = try InvoiceDomainRules.validatedStatus(
            rawValue: invoice.statusRawValue,
            paidAt: invoice.paidAt
        )
        let visits = InvoiceDomainRules.orderedVisits(
            invoice.invoiceVisits,
            locale: locale
        ).map { visit in
            InvoiceVisitDetail(
                id: visit.persistentModelID,
                visitDate: visit.visitDateSnapshot,
                serviceLocationName: visit.serviceLocationNameSnapshot,
                serviceLocationAddress: visit.serviceLocationAddressSnapshot,
                lineItems: InvoiceDomainRules.orderedLineItems(
                    visit.lineItems,
                    locale: locale
                ).map { lineItem in
                    InvoiceLineItemDetail(
                        id: lineItem.persistentModelID,
                        horseName: lineItem.horseNameSnapshot,
                        serviceName: lineItem.serviceNameSnapshot,
                        amountMinorUnits: lineItem.amountMinorUnits,
                        currencyCode: lineItem.currencyCode
                    )
                }
            )
        }
        return InvoiceDetail(
            id: invoice.persistentModelID,
            number: try InvoiceDomainRules.formattedNumber(invoice.number),
            invoiceDate: invoice.invoiceDate,
            dueDate: invoice.dueDate,
            note: invoice.note,
            status: status,
            paidAt: invoice.paidAt,
            businessName: invoice.businessNameSnapshot,
            businessPhone: invoice.businessPhoneSnapshot,
            businessEmail: invoice.businessEmailSnapshot,
            businessAddress: invoice.businessAddressSnapshot,
            clientName: invoice.clientNameSnapshot,
            clientPhone: invoice.clientPhoneSnapshot,
            clientEmail: invoice.clientEmailSnapshot,
            visits: visits,
            total: total(for: invoice)
        )
    }

    private static func total(for invoice: Invoice) -> MoneyAvailability {
        let amounts = invoice.invoiceVisits.flatMap(\.lineItems).map(\.amountMinorUnits)
        guard let total = try? InvoiceDomainRules.checkedTotal(amounts) else {
            return .unavailable
        }
        return .available(total)
    }
}
