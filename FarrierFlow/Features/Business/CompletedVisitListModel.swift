import Foundation
import Observation
import OSLog
import SwiftData

nonisolated struct CompletedVisitSummary: Identifiable, Equatable {
    let id: PersistentIdentifier
    let startedAt: Date
    let completedAt: Date?
    var recordedAt: Date { completedAt ?? startedAt }
    let locationName: String
    let horseNames: [String]
}

@MainActor
@Observable
final class CompletedVisitListModel {
    private static let logger = Logger(subsystem: "com.farrierflow.yusufcan.FarrierFlow", category: "CompletedVisits")
    private(set) var visits: [CompletedVisitSummary] = []
    private(set) var loadFailed = false

    func load(in context: ModelContext, during period: DateInterval? = nil, locale: Locale) {
        do {
            visits = try Self.summaries(in: ModelContext(context.container), during: period, locale: locale)
            loadFailed = false
        } catch {
            Self.logger.error("Completed visits unavailable: \(error, privacy: .public)")
            visits = []
            loadFailed = true
        }
    }

    static func summaries(in context: ModelContext, during period: DateInterval? = nil, locale: Locale) throws -> [CompletedVisitSummary] {
        let start = period?.start ?? .distantPast
        let end = period?.end ?? .distantFuture
        let includesDetachedWork = period == nil
        let descriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { visit in
                (visit.completedAt.flatMap { date in date >= start && date < end } ?? false)
                    || (includesDetachedWork && visit.appointment == nil)
            },
            sortBy: [SortDescriptor(\Visit.completedAt, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        let summaries: [CompletedVisitSummary] = try records.map { visit in
            let completedAt = visit.completedAt
            guard completedAt.map({ $0 >= visit.startedAt && $0.timeIntervalSinceReferenceDate.isFinite }) ?? true,
                  visit.startedAt.timeIntervalSinceReferenceDate.isFinite,
                  TextNormalization.required(visit.serviceLocationNameSnapshot) != nil,
                  !visit.visitHorses.isEmpty else {
                throw VisitDetailLoadError.invalidVisit
            }
            let horses: [String] = try visit.visitHorses.map { visitHorse in
                guard visitHorse.visit === visit, let horse = visitHorse.horse,
                      TextNormalization.required(horse.name) != nil,
                      let outcome = VisitOutcome(rawValue: visitHorse.outcomeRawValue),
                      completedAt == nil || outcome != .pending else {
                    throw VisitDetailLoadError.invalidVisit
                }
                return horse.name
            }
            let orderedNames = horses.sorted { left, right in
                left.compare(right, options: [.caseInsensitive, .numeric], range: nil, locale: locale) == .orderedAscending
            }
            return CompletedVisitSummary(id: visit.persistentModelID, startedAt: visit.startedAt, completedAt: completedAt,
                                         locationName: visit.serviceLocationNameSnapshot, horseNames: orderedNames)
        }
        return summaries.sorted {
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt > $1.recordedAt }
            return $0.id < $1.id
        }
    }
}
