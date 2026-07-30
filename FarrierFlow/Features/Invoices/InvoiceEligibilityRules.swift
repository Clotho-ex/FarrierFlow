import Foundation
import SwiftData

nonisolated enum InvoiceEligibilityError: Error, Equatable {
    case clientUnavailable
    case invalidVisit
    case invalidSourceRelationship
    case invalidWorkItem
    case subtotalOverflow
}

@MainActor
enum InvoiceEligibilityRules {
    static func choices(
        for clientID: PersistentIdentifier,
        in context: ModelContext
    ) throws -> [InvoiceVisitChoice] {
        guard let client = try context.existingModel(Client.self, for: clientID) else {
            throw InvoiceEligibilityError.clientUnavailable
        }

        let visits = try context.fetch(FetchDescriptor<Visit>())
        let choices = try visits.compactMap { visit -> InvoiceVisitChoice? in
            let workItems = try eligibleWorkItems(for: client, in: visit)
            guard !workItems.isEmpty else {
                return nil
            }
            let subtotal: Int64
            do {
                subtotal = try CheckedMoneyTotal.sum(workItems.map(\.amountMinorUnits))
            } catch {
                throw InvoiceEligibilityError.subtotalOverflow
            }
            return InvoiceVisitChoice(
                id: visit.persistentModelID,
                visitDate: visit.startedAt,
                serviceLocationName: visit.serviceLocationNameSnapshot,
                eligibleWorkItemCount: workItems.count,
                subtotalMinorUnits: subtotal
            )
        }

        return choices.sorted { left, right in
            if left.visitDate != right.visitDate {
                return left.visitDate < right.visitDate
            }
            let nameOrder = left.serviceLocationName.localizedStandardCompare(
                right.serviceLocationName
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return String(describing: left.id) < String(describing: right.id)
        }
    }

    static func eligibleWorkItems(
        for client: Client,
        in visit: Visit
    ) throws -> [WorkItem] {
        guard let completedAt = visit.completedAt else {
            return []
        }
        guard
            completedAt >= visit.startedAt,
            TextNormalization.required(visit.serviceLocationNameSnapshot)
                == visit.serviceLocationNameSnapshot
        else {
            throw InvoiceEligibilityError.invalidVisit
        }
        if let address = visit.serviceLocationAddressSnapshot,
           TextNormalization.optional(address) != address {
            throw InvoiceEligibilityError.invalidVisit
        }

        var workItems = [WorkItem]()
        for visitHorse in visit.visitHorses {
            guard visitHorse.visit === visit, let horse = visitHorse.horse,
                  horse.client != nil
            else {
                throw InvoiceEligibilityError.invalidSourceRelationship
            }

            for workItem in visitHorse.workItems {
                guard
                    workItem.visitHorse === visitHorse,
                    let service = workItem.service,
                    service.workItems.contains(where: { $0 === workItem }),
                    TextNormalization.required(workItem.serviceNameSnapshot)
                        == workItem.serviceNameSnapshot,
                    workItem.amountMinorUnits >= 0,
                    workItem.currencyCode == "USD"
                else {
                    throw InvoiceEligibilityError.invalidWorkItem
                }
                guard horse.client === client, workItem.invoiceLineItem == nil else {
                    continue
                }
                workItems.append(workItem)
            }
        }

        return orderedWorkItems(workItems)
    }

    static func orderedVisits(_ visits: [Visit]) -> [Visit] {
        visits.sorted { left, right in
            if left.startedAt != right.startedAt {
                return left.startedAt < right.startedAt
            }
            let nameOrder = left.serviceLocationNameSnapshot.localizedStandardCompare(
                right.serviceLocationNameSnapshot
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return String(describing: left.persistentModelID)
                < String(describing: right.persistentModelID)
        }
    }

    private static func orderedWorkItems(_ workItems: [WorkItem]) -> [WorkItem] {
        workItems.sorted { left, right in
            let leftHorseName = left.visitHorse?.horse?.name ?? ""
            let rightHorseName = right.visitHorse?.horse?.name ?? ""
            let horseOrder = leftHorseName.localizedStandardCompare(rightHorseName)
            if horseOrder != .orderedSame {
                return horseOrder == .orderedAscending
            }
            let serviceOrder = left.serviceNameSnapshot.localizedStandardCompare(
                right.serviceNameSnapshot
            )
            if serviceOrder != .orderedSame {
                return serviceOrder == .orderedAscending
            }
            if left.amountMinorUnits != right.amountMinorUnits {
                return left.amountMinorUnits < right.amountMinorUnits
            }
            return String(describing: left.persistentModelID)
                < String(describing: right.persistentModelID)
        }
    }
}
