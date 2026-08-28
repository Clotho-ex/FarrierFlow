import Foundation

nonisolated struct InvoicePDFContent: Sendable, Equatable {
    let number: String
    let invoiceDate: Date
    let dueDate: Date?
    let status: InvoiceStatus
    let payment: PaymentContent?
    let currencyCode: String
    let businessName: String
    let businessPhone: String?
    let businessEmail: String?
    let businessAddress: String?
    let clientName: String
    let clientPhone: String?
    let clientEmail: String?
    let visits: [VisitGroup]
    let totalMinorUnits: Int64
    let note: String?

    nonisolated struct PaymentContent: Sendable, Equatable {
        let amountMinorUnits: Int64
        let receivedAt: Date
        let method: PaymentMethod
        let otherDescription: String?
        let reference: String?
    }

    nonisolated struct VisitGroup: Sendable, Equatable {
        let date: Date
        let location: String
        let address: String?
        let lineItems: [LineItem]
    }

    nonisolated struct LineItem: Sendable, Equatable {
        let horseName: String
        let serviceName: String
        let amountMinorUnits: Int64
    }
}
