import SwiftData

enum InvoiceRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
    case create(PersistentIdentifier)
}
