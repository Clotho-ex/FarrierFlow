import SwiftData

enum ClientRoute: Hashable {
    case detail(PersistentIdentifier)
    case horse(PersistentIdentifier)
}
