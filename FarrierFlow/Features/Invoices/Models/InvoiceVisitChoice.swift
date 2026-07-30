import Foundation
import SwiftData

nonisolated struct InvoiceVisitChoice: Identifiable, Equatable {
    let id: PersistentIdentifier
    let visitDate: Date
    let serviceLocationName: String
    let eligibleWorkItemCount: Int
    let subtotalMinorUnits: Int64
}
