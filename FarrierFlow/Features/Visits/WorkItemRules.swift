import Foundation
import SwiftData

nonisolated enum WorkItemDraftViolation: Error, Equatable {
    case duplicateService
    case serviceNameSnapshotRequired
    case negativeAmount
    case unsupportedCurrency
    case subtotalOverflow
}

nonisolated enum WorkItemRules {
    static func violation(in workItems: [WorkItemDraft]) -> WorkItemDraftViolation? {
        var serviceIDs = Set<PersistentIdentifier>()
        for workItem in workItems {
            guard serviceIDs.insert(workItem.serviceID).inserted else {
                return .duplicateService
            }
            guard TextNormalization.required(workItem.serviceNameSnapshot) == workItem.serviceNameSnapshot else {
                return .serviceNameSnapshotRequired
            }
            guard workItem.amountMinorUnits >= 0 else {
                return .negativeAmount
            }
            guard workItem.currencyCode == "USD" else {
                return .unsupportedCurrency
            }
        }
        return nil
    }

    static func subtotal(for workItems: [WorkItemDraft]) throws -> Int64 {
        do {
            return try CheckedMoneyTotal.sum(workItems.map(\.amountMinorUnits))
        } catch CheckedMoneyTotalError.negativeAmount {
            throw WorkItemDraftViolation.negativeAmount
        } catch {
            throw WorkItemDraftViolation.subtotalOverflow
        }
    }

    static func sorted(_ workItems: [WorkItemDraft], locale: Locale = .current) -> [WorkItemDraft] {
        workItems.sorted { left, right in
            let nameOrder = left.serviceNameSnapshot.compare(
                right.serviceNameSnapshot,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric],
                locale: locale
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            if left.amountMinorUnits != right.amountMinorUnits {
                return left.amountMinorUnits < right.amountMinorUnits
            }
            if left.serviceID != right.serviceID {
                return String(describing: left.serviceID) < String(describing: right.serviceID)
            }
            let leftID = left.persistentID.map { String(describing: $0) } ?? left.id.uuidString
            let rightID = right.persistentID.map { String(describing: $0) } ?? right.id.uuidString
            return leftID < rightID
        }
    }
}
