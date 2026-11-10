import SwiftData

nonisolated struct VisitHorseDraft: Equatable, Identifiable {
    let id: PersistentIdentifier
    let horseID: PersistentIdentifier
    let horseName: String
    var outcome: VisitOutcome
    var workNotes: String
    var workItems: [WorkItemDraft] = []
    var plannedService: ServiceChoice? = nil
    var plannedServiceIsArchived = false

    var hasRecordedOutcome: Bool {
        switch outcome {
        case .pending:
            false
        case .notServiced:
            workItems.isEmpty
        case .serviced:
            !workItems.isEmpty && WorkItemRules.violation(in: workItems) == nil
        }
    }
}

nonisolated struct VisitDraft: Equatable {
    let visitID: PersistentIdentifier
    var horses: [VisitHorseDraft]

    init(
        visitID: PersistentIdentifier,
        horses: [VisitHorseDraft]
    ) {
        self.visitID = visitID
        self.horses = horses
    }
}

nonisolated enum VisitRecordedTotal: Equatable {
    case none
    case available(minorUnits: Int64, currencyCode: String)
    case unavailable
}

extension VisitDraft {
    var recordedTotal: VisitRecordedTotal {
        let recordedHorses = horses.filter { !$0.workItems.isEmpty }
        guard !recordedHorses.isEmpty else { return .none }
        guard recordedHorses.allSatisfy({ WorkItemRules.violation(in: $0.workItems) == nil }) else { return .unavailable }
        let items = recordedHorses.flatMap(\.workItems)
        guard let currency = items.first?.currencyCode,
              items.allSatisfy({ $0.currencyCode == currency }),
              let amount = try? CheckedMoneyTotal.sum(items.map(\.amountMinorUnits)) else {
            return .unavailable
        }
        return .available(minorUnits: amount, currencyCode: currency)
    }
}
