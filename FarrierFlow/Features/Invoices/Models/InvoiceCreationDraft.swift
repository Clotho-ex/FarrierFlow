import Foundation
import SwiftData

nonisolated struct InvoiceCreationDraft: Equatable {
    let clientID: PersistentIdentifier
    var selectedVisitIDs: Set<PersistentIdentifier>
    var invoiceDate: Date
    var dueDate: Date?
    var note: String
}
