import Foundation
import SwiftData

@MainActor
enum InvoiceProjection {
    static func summary(from invoice: Invoice, locale: Locale) throws -> InvoiceSummary {
        let total = total(for: invoice)
        guard case .available(let totalMinorUnits) = total else {
            throw CheckedMoneyTotalError.overflow
        }
        let status = try InvoiceDomainRules.validatedStatus(
            rawValue: invoice.statusRawValue,
            payments: invoice.payments,
            invoiceCurrencyCode: invoice.currencyCode,
            totalMinorUnits: totalMinorUnits
        )
        return InvoiceSummary(
            id: invoice.persistentModelID,
            number: try InvoiceDomainRules.formattedNumber(invoice.number),
            clientName: invoice.clientNameSnapshot,
            invoiceDate: invoice.invoiceDate,
            total: total,
            status: status
        )
    }

    static func detail(from invoice: Invoice, locale: Locale) throws -> InvoiceDetail {
        let total = total(for: invoice)
        guard case .available(let totalMinorUnits) = total else {
            throw CheckedMoneyTotalError.overflow
        }
        let status = try InvoiceDomainRules.validatedStatus(
            rawValue: invoice.statusRawValue,
            payments: invoice.payments,
            invoiceCurrencyCode: invoice.currencyCode,
            totalMinorUnits: totalMinorUnits
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
            payment: try invoice.payments.first.map(paymentDetail),
            businessName: invoice.businessNameSnapshot,
            businessPhone: invoice.businessPhoneSnapshot,
            businessEmail: invoice.businessEmailSnapshot,
            businessAddress: invoice.businessAddressSnapshot,
            clientName: invoice.clientNameSnapshot,
            clientPhone: invoice.clientPhoneSnapshot,
            clientEmail: invoice.clientEmailSnapshot,
            visits: visits,
            total: total,
            currencyCode: invoice.currencyCode
        )
    }

    private static func paymentDetail(_ payment: Payment) throws -> PaymentDetail {
        guard let method = payment.method, let source = payment.source else {
            throw InvoiceDomainRuleError.invalidStatus
        }
        return PaymentDetail(
            amountMinorUnits: payment.amountMinorUnits,
            currencyCode: payment.currencyCode,
            receivedAt: payment.receivedAt,
            method: method,
            source: source,
            otherDescription: payment.otherDescription,
            reference: payment.reference,
            note: payment.note
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
