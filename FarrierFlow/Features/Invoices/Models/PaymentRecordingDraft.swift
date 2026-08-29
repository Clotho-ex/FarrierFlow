import Foundation

nonisolated struct PaymentRecordingDraft: Equatable {
    var method: PaymentMethod? {
        didSet {
            if method != .other {
                otherDescription = ""
            }
        }
    }
    let amountMinorUnits: Int64
    let currencyCode: String
    var receivedAt: Date
    var otherDescription = ""
    var reference = ""
    var note = ""
}
