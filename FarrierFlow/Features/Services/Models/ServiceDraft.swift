nonisolated struct ServiceDraft: Equatable {
    var name: String = ""
    var priceInput: String = ""
}

nonisolated struct ServiceValues: Equatable {
    let name: String
    let defaultAmountMinorUnits: Int64
    let currencyCode: String
}
