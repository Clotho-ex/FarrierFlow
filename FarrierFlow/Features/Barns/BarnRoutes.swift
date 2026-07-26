import SwiftData

enum BarnRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
}
