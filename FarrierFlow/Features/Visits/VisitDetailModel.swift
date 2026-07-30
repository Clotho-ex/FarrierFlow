import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum VisitDetailLoadState: Equatable {
    case loading
    case loaded
    case failed
}

nonisolated struct VisitWorkItemResult: Equatable, Identifiable {
    let id: PersistentIdentifier
    let serviceID: PersistentIdentifier?
    let serviceNameSnapshot: String
    let amountMinorUnits: Int64
    let serviceIsArchived: Bool?
}

nonisolated struct VisitHorseResult: Equatable, Identifiable {
    let id: PersistentIdentifier
    let horseID: PersistentIdentifier
    let horseName: String
    let outcome: VisitOutcome
    let workNotes: String?
    let workItems: [VisitWorkItemResult]
    let subtotal: MoneyAvailability
}

nonisolated struct VisitDetail: Equatable {
    let visitID: PersistentIdentifier
    let startedAt: Date
    let completedAt: Date?
    let serviceLocationNameSnapshot: String
    let serviceLocationAddressSnapshot: String?
    let barnID: PersistentIdentifier?
    let horses: [VisitHorseResult]
    let total: MoneyAvailability
    let isCorrectionLocked: Bool
}

nonisolated enum VisitDetailLoadError: Error, Equatable {
    case visitUnavailable
    case invalidVisit
}

@MainActor
@Observable
final class VisitDetailModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "VisitDetail"
    )

    @ObservationIgnored
    private let context: ModelContext
    @ObservationIgnored
    private let loading: (PersistentIdentifier, ModelContext, Locale) throws -> VisitDetail

    private(set) var loadState: VisitDetailLoadState = .loading
    private(set) var detail: VisitDetail?
    private(set) var editorMode: VisitEditorMode = .inProgress
    private(set) var isCorrectionLocked = false
    var alert: FeatureAlert?

    let visitID: PersistentIdentifier

    init(
        visitID: PersistentIdentifier,
        in container: ModelContainer,
        loading: @escaping (PersistentIdentifier, ModelContext, Locale) throws -> VisitDetail = {
            try VisitDetailModel.loadDetail(visitID: $0, in: $1, locale: $2)
        }
    ) {
        self.visitID = visitID
        context = ModelContext(container)
        self.loading = loading
    }

    func load(locale: Locale = .current) {
        loadState = .loading
        do {
            let loadedDetail = try loading(visitID, context, locale)
            detail = loadedDetail
            editorMode = loadedDetail.completedAt == nil ? .inProgress : .correction
            isCorrectionLocked = loadedDetail.isCorrectionLocked
            alert = nil
            loadState = .loaded
        } catch {
            loadState = .failed
            detail = nil
            isCorrectionLocked = false
            Self.logger.error("Failed to load visit detail: \(error, privacy: .public)")
            alert = FeatureAlert(
                title: "Visit Unavailable",
                message: "The visit couldn’t be loaded. Try again."
            )
        }
    }

    func retry(locale: Locale = .current) {
        load(locale: locale)
    }

    static func loadDetail(
        visitID: PersistentIdentifier,
        in context: ModelContext,
        locale: Locale = .current
    ) throws -> VisitDetail {
        guard let visit = try context.existingModel(Visit.self, for: visitID) else {
            throw VisitDetailLoadError.visitUnavailable
        }
        try validateForDetail(visit)

        let horses = try visit.visitHorses.map { visitHorse in
            guard visitHorse.visit === visit, let horse = visitHorse.horse,
                  let outcome = VisitOutcome(rawValue: visitHorse.outcomeRawValue)
            else {
                throw VisitDetailLoadError.invalidVisit
            }
            let workItems = try workItemResults(for: visitHorse, locale: locale)
            return VisitHorseResult(
                id: visitHorse.persistentModelID,
                horseID: horse.persistentModelID,
                horseName: horse.name,
                outcome: outcome,
                workNotes: TextNormalization.optional(visitHorse.workNotes ?? ""),
                workItems: workItems,
                subtotal: try CheckedMoneyTotal.projectedSubtotal(
                    workItems.map(\.amountMinorUnits),
                    unavailableWhenEmpty: false
                )
            )
        }.sorted { lhs, rhs in
            let horseNameOrder = lhs.horseName.compare(
                rhs.horseName,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: locale
            )
            if horseNameOrder != .orderedSame {
                return horseNameOrder == .orderedAscending
            }
            return lhs.id < rhs.id
        }

        return VisitDetail(
            visitID: visitID,
            startedAt: visit.startedAt,
            completedAt: visit.completedAt,
            serviceLocationNameSnapshot: visit.serviceLocationNameSnapshot,
            serviceLocationAddressSnapshot: visit.serviceLocationAddressSnapshot,
            barnID: visit.barn?.persistentModelID,
            horses: horses,
            total: try CheckedMoneyTotal.projectedTotal(horses.map(\.subtotal)),
            isCorrectionLocked: InvoiceDomainRules.isCorrectionLocked(visit)
        )
    }

    private static func workItemResults(
        for visitHorse: VisitHorse,
        locale: Locale
    ) throws -> [VisitWorkItemResult] {
        let results = try visitHorse.workItems.map { workItem in
            guard
                workItem.visitHorse === visitHorse,
                TextNormalization.required(workItem.serviceNameSnapshot)
                    == workItem.serviceNameSnapshot,
                workItem.amountMinorUnits >= 0,
                workItem.currencyCode == "USD"
            else {
                throw VisitDetailLoadError.invalidVisit
            }

            if let service = workItem.service,
               !service.workItems.contains(where: {
                   $0.persistentModelID == workItem.persistentModelID
               }) {
                throw VisitDetailLoadError.invalidVisit
            }

            return VisitWorkItemResult(
                id: workItem.persistentModelID,
                serviceID: workItem.service?.persistentModelID,
                serviceNameSnapshot: workItem.serviceNameSnapshot,
                amountMinorUnits: workItem.amountMinorUnits,
                serviceIsArchived: workItem.service?.isArchived
            )
        }

        return results.sorted { lhs, rhs in
            let nameOrder = lhs.serviceNameSnapshot.compare(
                rhs.serviceNameSnapshot,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric],
                range: nil,
                locale: locale
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            if lhs.amountMinorUnits != rhs.amountMinorUnits {
                return lhs.amountMinorUnits < rhs.amountMinorUnits
            }
            let leftServiceID = lhs.serviceID.map(String.init(describing:)) ?? ""
            let rightServiceID = rhs.serviceID.map(String.init(describing:)) ?? ""
            if leftServiceID != rightServiceID {
                return leftServiceID < rightServiceID
            }
            return lhs.id < rhs.id
        }
    }

    // A missing persisted Visit.barn is the sole tolerated invalid relationship:
    // immutable snapshots still make the historical record readable. All other
    // Visit invariants remain required before detail UI can present data.
    private static func validateForDetail(_ visit: Visit) throws {
        guard
            let appointment = visit.appointment,
            appointment.visit === visit,
            let appointmentBarn = appointment.barn,
            TextNormalization.required(visit.serviceLocationNameSnapshot) != nil,
            !appointment.appointmentHorses.isEmpty,
            !visit.visitHorses.isEmpty
        else {
            throw VisitDetailLoadError.invalidVisit
        }

        if let visitBarn = visit.barn, visitBarn !== appointmentBarn {
            throw VisitDetailLoadError.invalidVisit
        }

        var appointmentHorseIDs = Set<PersistentIdentifier>()
        for appointmentHorse in appointment.appointmentHorses {
            guard
                appointmentHorse.appointment === appointment,
                let horse = appointmentHorse.horse,
                horse.client != nil,
                horse.currentBarn != nil,
                appointmentHorseIDs.insert(horse.persistentModelID).inserted
            else {
                throw VisitDetailLoadError.invalidVisit
            }
        }

        var visitHorseIDs = Set<PersistentIdentifier>()
        var containsPendingOutcome = false
        var containsServicedOutcome = false
        for visitHorse in visit.visitHorses {
            guard
                visitHorse.visit === visit,
                let horse = visitHorse.horse,
                horse.client != nil,
                horse.currentBarn != nil,
                visitHorseIDs.insert(horse.persistentModelID).inserted,
                let outcome = VisitOutcome(rawValue: visitHorse.outcomeRawValue)
            else {
                throw VisitDetailLoadError.invalidVisit
            }
            guard
                TextNormalization.optional(visitHorse.workNotes ?? "") == nil
                    || outcome == .serviced
            else {
                throw VisitDetailLoadError.invalidVisit
            }
            guard outcome != .notServiced || visitHorse.workItems.isEmpty else {
                throw VisitDetailLoadError.invalidVisit
            }
            guard visit.completedAt == nil
                || outcome != .serviced
                || !visitHorse.workItems.isEmpty
            else {
                throw VisitDetailLoadError.invalidVisit
            }
            containsPendingOutcome = containsPendingOutcome || outcome == .pending
            containsServicedOutcome = containsServicedOutcome || outcome == .serviced
        }

        guard visitHorseIDs == appointmentHorseIDs else {
            throw VisitDetailLoadError.invalidVisit
        }

        if let completedAt = visit.completedAt {
            guard
                completedAt >= visit.startedAt,
                !containsPendingOutcome,
                containsServicedOutcome
            else {
                throw VisitDetailLoadError.invalidVisit
            }
        } else {
            // A completed Visit permits later relocation. An in-progress Visit
            // retains the original Appointment location invariant.
            guard visit.visitHorses.allSatisfy({ $0.horse?.currentBarn === appointmentBarn }) else {
                throw VisitDetailLoadError.invalidVisit
            }
        }
    }
}
