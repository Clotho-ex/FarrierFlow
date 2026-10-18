import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class BusinessProfile: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var name: String
        var phone: String?
        var email: String?
        var address: String?
        var defaultInvoiceNote: String?
        var defaultAppointmentDurationMinutes: Int?
        var defaultInvoiceDueDays: Int?
        var nextInvoiceNumber: Int64
        var currencyCode: String = "USD"

        init(
            syncID: UUID = UUID(),
            name: String,
            phone: String? = nil,
            email: String? = nil,
            address: String? = nil,
            defaultInvoiceNote: String? = nil,
            defaultAppointmentDurationMinutes: Int? = nil,
            defaultInvoiceDueDays: Int? = 14,
            nextInvoiceNumber: Int64 = 1,
            currencyCode: String = "USD"
        ) {
            self.syncID = syncID
            self.name = name
            self.phone = phone
            self.email = email
            self.address = address
            self.defaultInvoiceNote = defaultInvoiceNote
            self.defaultAppointmentDurationMinutes = defaultAppointmentDurationMinutes
            self.defaultInvoiceDueDays = defaultInvoiceDueDays
            self.nextInvoiceNumber = nextInvoiceNumber
            self.currencyCode = currencyCode
        }
    }
}
