nonisolated struct BusinessProfileDraft: Equatable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var defaultInvoiceNote: String = ""
    var defaultAppointmentDurationMinutes: Int?
    var defaultInvoiceDueDays: Int? = 14
}

nonisolated struct BusinessProfileValues: Equatable {
    let name: String
    let phone: String?
    let email: String?
    let address: String?
    let defaultInvoiceNote: String?
    let defaultAppointmentDurationMinutes: Int?
    let defaultInvoiceDueDays: Int?

    init(
        name: String,
        phone: String?,
        email: String?,
        address: String?,
        defaultInvoiceNote: String?,
        defaultAppointmentDurationMinutes: Int? = nil,
        defaultInvoiceDueDays: Int? = 14
    ) {
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.defaultInvoiceNote = defaultInvoiceNote
        self.defaultAppointmentDurationMinutes = defaultAppointmentDurationMinutes
        self.defaultInvoiceDueDays = defaultInvoiceDueDays
    }
}
