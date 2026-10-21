import Foundation

nonisolated enum SyncBatchPlanner {
    private static let referenceFields: [SyncRecordKind: [String]] = [
        .horse: ["client", "currentBarn", "defaultService"],
        .appointment: ["barn"],
        .appointmentHorse: ["appointment", "horse", "plannedService"],
        .visit: ["appointment", "barn"],
        .visitHorse: ["visit", "horse"],
        .photograph: ["visitHorse"],
        .workItem: ["service", "visitHorse", "billingHoldID"],
        .invoice: ["client"],
        .invoiceVisit: ["invoice", "sourceVisit"],
        .invoiceLineItem: ["invoiceVisit", "sourceWorkItem"],
        .payment: ["invoice"],
    ]

    private static let ownedChildren: [SyncRecordKind: [(SyncRecordKind, String)]] = [
        .appointment: [(.appointmentHorse, "appointment"), (.visit, "appointment")],
        .visit: [(.visitHorse, "visit")],
        .visitHorse: [(.workItem, "visitHorse"), (.photograph, "visitHorse")],
        .invoice: [(.invoiceVisit, "invoice"), (.payment, "invoice")],
        .invoiceVisit: [(.invoiceLineItem, "invoiceVisit")],
    ]

    static func select(
        from mutations: [SyncMutation], baseline: [SyncRecord],
        headerBytes: Int, softLimit: Int = 200, byteLimit: Int = 8 * 1_024 * 1_024
    ) throws -> [SyncMutation] {
        let byID = Dictionary(uniqueKeysWithValues: mutations.map { ($0.id, $0) })
        let old = try SyncJournal.index(baseline)
        var graph = old
        for mutation in mutations { graph[mutation.id] = mutation.record }
        var references: [UUID: Set<UUID>] = [:]
        var children: [UUID: Set<UUID>] = [:]
        var dependents: [UUID: Set<UUID>] = [:]
        for record in baseline + mutations.compactMap(\.record) {
            let ids = try referencedIDs(record)
            references[record.id, default: []].formUnion(ids)
            for id in ids { dependents[id, default: []].insert(record.id) }
            for (parentKind, relationships) in ownedChildren {
                for (childKind, field) in relationships where record.kind == childKind {
                    if let parent = try reference(record.fields[field]) {
                        if graph[parent]?.kind == parentKind || old[parent]?.kind == parentKind {
                            children[parent, default: []].insert(record.id)
                        }
                    }
                }
            }
        }
        var membershipsByHorse: [UUID: Set<UUID>] = [:]
        for record in graph.values where record.kind == .appointmentHorse {
            if let horse = try reference(record.fields["horse"]) {
                membershipsByHorse[horse, default: []].insert(record.id)
            }
        }
        let sizes = try Dictionary(uniqueKeysWithValues: mutations.map {
            ($0.id, try JSONEncoder().encode($0).count + 1)
        })
        let ordered = mutations.sorted {
            let first = SyncRecordKind.allCases.firstIndex(of: $0.kind) ?? 0
            let second = SyncRecordKind.allCases.firstIndex(of: $1.kind) ?? 0
            return first == second ? $0.id.uuidString < $1.id.uuidString : first < second
        }
        let witnesses = Set(children.values.flatMap { $0 })
        var chosen = Set<UUID>()
        var chosenBytes = headerBytes
        for seed in ordered where !chosen.contains(seed.id) {
            var group = Set<UUID>()
            var visiting = [seed.id]
            var visited = Set<UUID>()
            while let id = visiting.popLast() {
                guard visited.insert(id).inserted else { continue }
                if chosen.contains(id) { continue }
                if let mutation = byID[id] {
                    group.insert(id)
                    visiting.append(contentsOf: references[id] ?? [])
                    visiting.append(contentsOf: children[id] ?? [])
                    if mutation.record == nil {
                        visiting.append(contentsOf: dependents[id] ?? [])
                    }
                    if mutation.kind == .horse,
                       old[id]?.fields["currentBarn"] != mutation.record?.fields["currentBarn"],
                       old[id] != nil {
                        visiting.append(contentsOf: membershipsByHorse[id] ?? [])
                    }
                    if mutation.kind == .businessProfile {
                        let currency = mutation.record?.fields["currencyCode"]
                        if baseline.contains(where: {
                            $0.fields["currencyCode"] != nil && $0.fields["currencyCode"] != currency
                        }) {
                            visiting.append(contentsOf: mutations.filter {
                                $0.record?.fields["currencyCode"] != nil
                            }.map(\.id))
                        }
                    }
                } else if witnesses.contains(id) {
                    // An unchanged membership can connect two changed parents.
                    visiting.append(contentsOf: references[id] ?? [])
                }
            }
            let additions = group.subtracting(chosen)
            let bytes = additions.reduce(0) { $0 + (sizes[$1] ?? 0) }
            guard additions.count <= 10_000, headerBytes + bytes <= byteLimit else {
                throw SyncJournalError.batchTooLarge
            }
            if !chosen.isEmpty &&
               (chosen.count + additions.count > softLimit || chosenBytes + bytes > byteLimit) {
                continue
            }
            chosen.formUnion(additions)
            chosenBytes += bytes
            if chosen.count >= softLimit { break }
        }
        return ordered.filter { chosen.contains($0.id) }
    }

    private static func referencedIDs(_ record: SyncRecord) throws -> Set<UUID> {
        var ids = Set<UUID>()
        for field in referenceFields[record.kind] ?? [] {
            if let id = try reference(record.fields[field]) { ids.insert(id) }
        }
        return ids
    }

    private static func reference(_ value: SyncValue?) throws -> UUID? {
        guard let value, value != .null else { return nil }
        guard case .string(let string) = value, let id = UUID(uuidString: string) else {
            throw SyncJournalError.invalidMutation
        }
        return id
    }
}
