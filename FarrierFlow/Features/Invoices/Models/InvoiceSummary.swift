import Foundation
import SwiftData

nonisolated struct InvoiceSummary: Identifiable, Equatable {
    let id: PersistentIdentifier
    let number: String
    let clientName: String
    let invoiceDate: Date
    let total: MoneyAvailability
    let status: InvoiceStatus
}
