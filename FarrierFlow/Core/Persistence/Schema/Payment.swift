import Foundation
import SwiftData

nonisolated enum PaymentMethod: String, Codable, CaseIterable, Sendable {
    case cash
    case bankTransfer
    case card
    case cheque
    case other

    var displayName: String {
        switch self {
        case .cash: String(localized: "Cash")
        case .bankTransfer: String(localized: "Bank Transfer")
        case .card: String(localized: "Card")
        case .cheque: String(localized: "Cheque")
        case .other: String(localized: "Other")
        }
    }
}

nonisolated enum PaymentRecordSource: String, Codable, Sendable {
    case manual
}

extension FarrierFlowSchemaV1 {
    @Model
    final class Payment {
        @Attribute(.unique) private(set) var id: UUID
        private(set) var amountMinorUnits: Int64
        private(set) var currencyCode: String
        private(set) var receivedAt: Date
        private(set) var methodRawValue: String
        private(set) var sourceRawValue: String
        private(set) var otherDescription: String?
        private(set) var reference: String?
        private(set) var note: String?
        private(set) var invoice: Invoice?

        var method: PaymentMethod? { PaymentMethod(rawValue: methodRawValue) }
        var source: PaymentRecordSource? { PaymentRecordSource(rawValue: sourceRawValue) }

        init(
            id: UUID = UUID(),
            amountMinorUnits: Int64,
            currencyCode: String,
            receivedAt: Date,
            method: PaymentMethod,
            source: PaymentRecordSource = .manual,
            otherDescription: String? = nil,
            reference: String? = nil,
            note: String? = nil,
            invoice: Invoice
        ) {
            self.id = id
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.receivedAt = receivedAt
            methodRawValue = method.rawValue
            sourceRawValue = source.rawValue
            self.otherDescription = otherDescription
            self.reference = reference
            self.note = note
            self.invoice = invoice
        }
    }
}
