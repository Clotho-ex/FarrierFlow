import Foundation
import SwiftData

extension FarrierFlowSchemaV1 {
    @Model
    final class Invoice {
        @Attribute(.unique) private(set) var number: Int64
        private(set) var invoiceDate: Date
        private(set) var dueDate: Date?
        private(set) var note: String?
        var statusRawValue: String
        var paidAt: Date?
        private(set) var clientNameSnapshot: String
        private(set) var clientPhoneSnapshot: String?
        private(set) var clientEmailSnapshot: String?
        private(set) var businessNameSnapshot: String
        private(set) var businessPhoneSnapshot: String?
        private(set) var businessEmailSnapshot: String?
        private(set) var businessAddressSnapshot: String?
        private(set) var currencyCode: String
        private(set) var client: Client?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \InvoiceVisit.invoice
        )
        var invoiceVisits: [InvoiceVisit] = []

        init(
            number: Int64,
            invoiceDate: Date,
            dueDate: Date? = nil,
            note: String? = nil,
            statusRawValue: String = "unpaid",
            paidAt: Date? = nil,
            clientNameSnapshot: String,
            clientPhoneSnapshot: String? = nil,
            clientEmailSnapshot: String? = nil,
            businessNameSnapshot: String,
            businessPhoneSnapshot: String? = nil,
            businessEmailSnapshot: String? = nil,
            businessAddressSnapshot: String? = nil,
            currencyCode: String = "USD",
            client: Client
        ) {
            self.number = number
            self.invoiceDate = invoiceDate
            self.dueDate = dueDate
            self.note = note
            self.statusRawValue = statusRawValue
            self.paidAt = paidAt
            self.clientNameSnapshot = clientNameSnapshot
            self.clientPhoneSnapshot = clientPhoneSnapshot
            self.clientEmailSnapshot = clientEmailSnapshot
            self.businessNameSnapshot = businessNameSnapshot
            self.businessPhoneSnapshot = businessPhoneSnapshot
            self.businessEmailSnapshot = businessEmailSnapshot
            self.businessAddressSnapshot = businessAddressSnapshot
            self.currencyCode = currencyCode
            self.client = client
        }
    }
}
