import SwiftData

extension FarrierFlowSchemaV1 {
    @Model
    final class BusinessProfile {
        var name: String
        var phone: String?
        var email: String?
        var address: String?
        var defaultInvoiceNote: String?
        var defaultAppointmentDurationMinutes: Int?
        var defaultInvoiceDueDays: Int?
        var nextInvoiceNumber: Int64

        init(
            name: String,
            phone: String? = nil,
            email: String? = nil,
            address: String? = nil,
            defaultInvoiceNote: String? = nil,
            defaultAppointmentDurationMinutes: Int? = nil,
            defaultInvoiceDueDays: Int? = 14,
            nextInvoiceNumber: Int64 = 1
        ) {
            self.name = name
            self.phone = phone
            self.email = email
            self.address = address
            self.defaultInvoiceNote = defaultInvoiceNote
            self.defaultAppointmentDurationMinutes = defaultAppointmentDurationMinutes
            self.defaultInvoiceDueDays = defaultInvoiceDueDays
            self.nextInvoiceNumber = nextInvoiceNumber
        }
    }
}
