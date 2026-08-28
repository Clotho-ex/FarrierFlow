import Foundation

nonisolated struct PaymentRecordingDraft: Equatable {
    var method: PaymentMethod?
    let amountMinorUnits: Int64
    let currencyCode: String
    var receivedAt: Date
    var otherDescription = ""
    var reference = ""
    var note = ""
}
