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
        var serviceMemberships: [ObjectIdentifier: Set<ObjectIdentifier>] = [:]
        return try visits.compactMap { visit in
            let work = try eligibleWorkItemsByClient(in: visit, serviceMemberships: &serviceMemberships)[client.persistentModelID] ?? []
            return try choice(for: visit, workItems: work)
        }.sorted(by: choicePrecedes)
    }

    static func firstChoicesByClient(in context: ModelContext) throws -> [PersistentIdentifier: InvoiceVisitChoice] {
        let visits = try context.fetch(FetchDescriptor<Visit>(predicate: #Predicate { $0.completedAt != nil }))
        var first: [PersistentIdentifier: InvoiceVisitChoice] = [:]
        var serviceMemberships: [ObjectIdentifier: Set<ObjectIdentifier>] = [:]
        for visit in visits {
            for (clientID, work) in try eligibleWorkItemsByClient(in: visit, serviceMemberships: &serviceMemberships) {
                guard let candidate = try choice(for: visit, workItems: work) else { continue }
                if let previous = first[clientID], !choicePrecedes(candidate, previous) { continue }
                first[clientID] = candidate
            }
        }
        return first
    }

    static func eligibleWorkItems(for client: Client, in visit: Visit) throws -> [WorkItem] {
        var serviceMemberships: [ObjectIdentifier: Set<ObjectIdentifier>] = [:]
        return orderedWorkItems(try eligibleWorkItemsByClient(in: visit, serviceMemberships: &serviceMemberships)[client.persistentModelID] ?? [])
    }

    private static func eligibleWorkItemsByClient(
        in visit: Visit, serviceMemberships: inout [ObjectIdentifier: Set<ObjectIdentifier>]
    ) throws -> [PersistentIdentifier: [WorkItem]] {
        guard let completedAt = visit.completedAt else { return [:] }
        guard completedAt >= visit.startedAt,
              TextNormalization.required(visit.serviceLocationNameSnapshot) == visit.serviceLocationNameSnapshot else {
            throw InvoiceEligibilityError.invalidVisit
        }
        if let address = visit.serviceLocationAddressSnapshot, TextNormalization.optional(address) != address {
            throw InvoiceEligibilityError.invalidVisit
        }
        var result: [PersistentIdentifier: [WorkItem]] = [:]
        for member in visit.visitHorses {
            guard member.visit === visit, let client = member.horse?.client else {
                throw InvoiceEligibilityError.invalidSourceRelationship
            }
            for item in member.workItems {
                guard item.visitHorse === member, let service = item.service else {
                    throw InvoiceEligibilityError.invalidWorkItem
                }
                let serviceID = ObjectIdentifier(service)
                if serviceMemberships[serviceID] == nil {
                    serviceMemberships[serviceID] = Set(service.workItems.map(ObjectIdentifier.init))
                }
                guard serviceMemberships[serviceID]?.contains(ObjectIdentifier(item)) == true,
                      TextNormalization.required(item.serviceNameSnapshot) == item.serviceNameSnapshot,
                      item.amountMinorUnits >= 0, BusinessCurrency.isSupported(item.currencyCode),
                      item.currencyCode == service.currencyCode else {
                    throw InvoiceEligibilityError.invalidWorkItem
                }
                guard item.invoiceLineItem == nil, item.billingHoldID == nil else { continue }
                result[client.persistentModelID, default: []].append(item)
            }
        }
        return result
    }

    private static func choice(for visit: Visit, workItems: [WorkItem]) throws -> InvoiceVisitChoice? {
        guard !workItems.isEmpty else { return nil }
        let subtotal: Int64
        do { subtotal = try CheckedMoneyTotal.sum(workItems.map(\.amountMinorUnits)) }
        catch { throw InvoiceEligibilityError.subtotalOverflow }
        guard let currency = workItems.first?.currencyCode,
              workItems.allSatisfy({ $0.currencyCode == currency }) else {
            throw InvoiceEligibilityError.invalidWorkItem
        }
        return InvoiceVisitChoice(id: visit.persistentModelID, visitDate: visit.startedAt,
            serviceLocationName: visit.serviceLocationNameSnapshot, eligibleWorkItemCount: workItems.count,
            subtotalMinorUnits: subtotal, currencyCode: currency)
    }

    private static func choicePrecedes(_ left: InvoiceVisitChoice, _ right: InvoiceVisitChoice) -> Bool {
        if left.visitDate != right.visitDate { return left.visitDate < right.visitDate }
        let order = left.serviceLocationName.localizedStandardCompare(right.serviceLocationName)
        if order != .orderedSame { return order == .orderedAscending }
        return String(describing: left.id) < String(describing: right.id)
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
