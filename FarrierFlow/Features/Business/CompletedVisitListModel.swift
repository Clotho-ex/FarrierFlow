import Foundation
import Observation
import OSLog
import SwiftData

nonisolated struct CompletedVisitSummary: Identifiable, Equatable {
    let id: PersistentIdentifier
    let completedAt: Date
    let locationName: String
    let horseNames: [String]
}

@MainActor
@Observable
final class CompletedVisitListModel {
    private static let logger = Logger(subsystem: "com.farrierflow.yusufcan.FarrierFlow", category: "CompletedVisits")
    private(set) var visits: [CompletedVisitSummary] = []
    private(set) var loadFailed = false

    func load(in context: ModelContext, during period: DateInterval, locale: Locale) {
        do {
            visits = try Self.summaries(in: ModelContext(context.container), during: period, locale: locale)
            loadFailed = false
        } catch {
            Self.logger.error("Completed visits unavailable: \(error, privacy: .public)")
            visits = []
            loadFailed = true
        }
    }

    static func summaries(in context: ModelContext, during period: DateInterval, locale: Locale) throws -> [CompletedVisitSummary] {
        let start = period.start
        let end = period.end
        let descriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { visit in
                visit.completedAt.flatMap { date in date >= start && date < end } ?? false
            },
            sortBy: [SortDescriptor(\Visit.completedAt, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        let summaries: [CompletedVisitSummary] = try records.map { visit in
            guard let completedAt = visit.completedAt, completedAt >= visit.startedAt,
                  completedAt.timeIntervalSinceReferenceDate.isFinite,
                  TextNormalization.required(visit.serviceLocationNameSnapshot) != nil,
                  !visit.visitHorses.isEmpty else {
                throw VisitDetailLoadError.invalidVisit
            }
            let horses: [String] = try visit.visitHorses.map { visitHorse in
                guard visitHorse.visit === visit, let horse = visitHorse.horse,
                      TextNormalization.required(horse.name) != nil,
                      let outcome = VisitOutcome(rawValue: visitHorse.outcomeRawValue), outcome != .pending else {
                    throw VisitDetailLoadError.invalidVisit
                }
                return horse.name
            }
            let orderedNames = horses.sorted { left, right in
                left.compare(right, options: [.caseInsensitive, .numeric], range: nil, locale: locale) == .orderedAscending
            }
            return CompletedVisitSummary(id: visit.persistentModelID, completedAt: completedAt,
                                         locationName: visit.serviceLocationNameSnapshot, horseNames: orderedNames)
        }
        return summaries.sorted {
            if $0.completedAt != $1.completedAt { return $0.completedAt > $1.completedAt }
            return $0.id < $1.id
        }
    }
}
