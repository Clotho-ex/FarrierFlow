import Foundation

nonisolated struct InvoicePDFContent: Sendable, Equatable {
    let number: String
    let invoiceDate: Date
    let dueDate: Date?
    let status: InvoiceStatus
    let paidAt: Date?
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
