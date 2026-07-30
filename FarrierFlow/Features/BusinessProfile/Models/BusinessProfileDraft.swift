nonisolated struct BusinessProfileDraft: Equatable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var defaultInvoiceNote: String = ""
}

nonisolated struct BusinessProfileValues: Equatable {
    let name: String
    let phone: String?
    let email: String?
    let address: String?
    let defaultInvoiceNote: String?
}
