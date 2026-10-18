import SwiftData

enum InvoiceRoute: Hashable {
    case list
    case history
    case detail(PersistentIdentifier)
    case create(PersistentIdentifier)
}
