import Foundation
import SwiftData

nonisolated struct InvoiceDetail: Equatable {
    let id: PersistentIdentifier
    let number: String
    let invoiceDate: Date
    let dueDate: Date?
    let note: String?
    let status: InvoiceStatus
    let paidAt: Date?
    let businessName: String
    let businessPhone: String?
    let businessEmail: String?
    let businessAddress: String?
    let clientName: String
    let clientPhone: String?
    let clientEmail: String?
    let visits: [InvoiceVisitDetail]
    let total: MoneyAvailability
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
