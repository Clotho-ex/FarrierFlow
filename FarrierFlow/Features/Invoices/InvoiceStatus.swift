import Foundation

nonisolated enum InvoiceStatus: String, CaseIterable, Codable {
    case unpaid
    case paid

    var displayName: String {
        switch self {
        case .unpaid: String(localized: "Unpaid")
        case .paid: String(localized: "Paid")
        }
    }
}
