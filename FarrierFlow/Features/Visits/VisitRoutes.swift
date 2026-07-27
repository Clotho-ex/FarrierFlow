import SwiftData

enum VisitPresentation: Identifiable {
    case editor(PersistentIdentifier)
    case detail(PersistentIdentifier)

    enum ID: Hashable {
        case editor(PersistentIdentifier)
        case detail(PersistentIdentifier)
    }

    var id: ID {
        switch self {
        case .editor(let id):
            .editor(id)
        case .detail(let id):
            .detail(id)
        }
    }
}
