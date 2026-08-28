import Foundation
import SwiftData

nonisolated struct InvoiceDetail: Equatable {
    let id: PersistentIdentifier
    let number: String
    let invoiceDate: Date
    let dueDate: Date?
    let note: String?
    let status: InvoiceStatus
    let payment: PaymentDetail?
    let businessName: String
    let businessPhone: String?
    let businessEmail: String?
    let businessAddress: String?
    let clientName: String
    let clientPhone: String?
    let clientEmail: String?
    let visits: [InvoiceVisitDetail]
    let total: MoneyAvailability
    let currencyCode: String
}

nonisolated struct PaymentDetail: Equatable {
    let amountMinorUnits: Int64
    let currencyCode: String
    let receivedAt: Date
    let method: PaymentMethod
    let source: PaymentRecordSource
    let otherDescription: String?
    let reference: String?
    let note: String?
}

nonisolated struct InvoiceVisitDetail: Identifiable, Equatable {
    let id: PersistentIdentifier
    let visitDate: Date
    let serviceLocationName: String
    let serviceLocationAddress: String?
    let lineItems: [InvoiceLineItemDetail]
}

nonisolated struct InvoiceLineItemDetail: Identifiable, Equatable {
    let id: PersistentIdentifier
    let horseName: String
    let serviceName: String
    let amountMinorUnits: Int64
    let currencyCode: String
}
