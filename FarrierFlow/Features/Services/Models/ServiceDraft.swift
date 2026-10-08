nonisolated struct ServiceDraft: Equatable {
    var name: String = ""
    var priceInput: String = ""
    var currencyCode: String = "USD"
}

nonisolated struct ServiceValues: Equatable {
    let name: String
    let defaultAmountMinorUnits: Int64
    let currencyCode: String
}
