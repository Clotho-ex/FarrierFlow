import SwiftData

nonisolated struct ServiceChoice: Identifiable, Equatable {
    let id: PersistentIdentifier
    let name: String
    let defaultAmountMinorUnits: Int64
    let currencyCode: String
}
