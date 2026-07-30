import Foundation
import SwiftData

nonisolated struct WorkItemDraft: Equatable, Identifiable {
    let id: UUID
    let persistentID: PersistentIdentifier?
    var serviceID: PersistentIdentifier
    var serviceNameSnapshot: String
    var amountMinorUnits: Int64
    let currencyCode: String
    let serviceIsArchived: Bool

    init(
        id: UUID = UUID(),
        persistentID: PersistentIdentifier? = nil,
        serviceID: PersistentIdentifier,
        serviceNameSnapshot: String,
        amountMinorUnits: Int64,
        currencyCode: String = "USD",
        serviceIsArchived: Bool = false
    ) {
        self.id = id
        self.persistentID = persistentID
        self.serviceID = serviceID
        self.serviceNameSnapshot = serviceNameSnapshot
        self.amountMinorUnits = amountMinorUnits
        self.currencyCode = currencyCode
        self.serviceIsArchived = serviceIsArchived
    }

    static func == (lhs: WorkItemDraft, rhs: WorkItemDraft) -> Bool {
        let sameIdentity: Bool
        switch (lhs.persistentID, rhs.persistentID) {
        case let (left?, right?):
            sameIdentity = left == right
        case (nil, nil):
            sameIdentity = lhs.id == rhs.id
        default:
            sameIdentity = false
        }
        return sameIdentity
            && lhs.serviceID == rhs.serviceID
            && lhs.serviceNameSnapshot == rhs.serviceNameSnapshot
            && lhs.amountMinorUnits == rhs.amountMinorUnits
            && lhs.currencyCode == rhs.currencyCode
            && lhs.serviceIsArchived == rhs.serviceIsArchived
    }
}
