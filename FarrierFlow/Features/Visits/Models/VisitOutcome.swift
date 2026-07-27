import Foundation

nonisolated enum VisitOutcome: String, CaseIterable, Codable, Hashable, Sendable {
    case pending
    case serviced
    case notServiced

    var localizedTitle: LocalizedStringResource {
        switch self {
        case .pending:
            "Pending"
        case .serviced:
            "Serviced"
        case .notServiced:
            "Not Serviced"
        }
    }
}
