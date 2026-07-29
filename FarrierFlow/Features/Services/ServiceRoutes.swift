import SwiftData

enum ServiceRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
}
