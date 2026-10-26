import SwiftData

enum ClientRoute: Hashable {
    case detail(PersistentIdentifier)
    case horse(PersistentIdentifier)
    case visit(PersistentIdentifier)
    case recordedWork(PersistentIdentifier)
    case appointment(PersistentIdentifier)
}
