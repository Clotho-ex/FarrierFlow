import Foundation
import Observation
import OSLog
import SwiftData

nonisolated struct HorseDefaultServiceDetail: Equatable {
    let name: String
    let formattedAmount: String
}

@MainActor
@Observable
final class HorseDetailModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "HorseDetail"
    )

    @ObservationIgnored
    private let historyLoading: (PersistentIdentifier, ModelContext, Locale) throws -> [HorseHistoryEntry]
    @ObservationIgnored
    private var historyContext: ModelContext?

    private(set) var horse: Horse?
    private(set) var history: [HorseHistoryEntry] = []
    private(set) var historyLoadState = HorseHistoryLoadState.loading
    private(set) var defaultService: HorseDefaultServiceDetail?
    private var historyHorseID: PersistentIdentifier?
    private var historyLocale = Locale.current
    var alert: FeatureAlert?

    init(
        historyLoading: @escaping (PersistentIdentifier, ModelContext, Locale) throws -> [HorseHistoryEntry] = {
            try HorseDetailModel.loadHistory(horseID: $0, in: $1, locale: $2)
        }
    ) {
        self.historyLoading = historyLoading
    }

    func load(
        id: PersistentIdentifier,
        in context: ModelContext,
        locale: Locale = .current
    ) {
        horse = context.model(for: id) as? Horse
        defaultService = horse.flatMap { horse in
            Self.defaultServiceDetail(for: horse, locale: locale)
        }
        historyHorseID = id
        historyContext = context
        historyLocale = locale
        loadHistory()
    }

    private static func defaultServiceDetail(
        for horse: Horse,
        locale: Locale
    ) -> HorseDefaultServiceDetail? {
        guard
            let service = horse.defaultService,
            TextNormalization.required(service.name) == service.name,
            service.defaultAmountMinorUnits >= 0,
            service.currencyCode == "USD",
            let formattedAmount = MoneyFormatter.usd(
                minorUnits: service.defaultAmountMinorUnits,
                locale: locale
            )
        else {
            return nil
        }
        return HorseDefaultServiceDetail(
            name: service.name,
            formattedAmount: formattedAmount
        )
    }

    func retryHistory() {
        loadHistory()
    }

    func delete(in context: ModelContext) -> Bool {
        guard let horse else { return false }
        self.horse = nil
        do {
            try RecordDeletionRules.delete(horse, in: context)
            return true
        } catch let block as RecordDeletionBlock {
            self.horse = horse
            alert = block.alert
            return false
        } catch {
            self.horse = horse
            alert = FeatureAlert(
                title: "Couldn’t Delete Horse",
                message: "The horse wasn’t deleted. Try again."
            )
            return false
        }
    }

    static func loadHistory(
        horseID: PersistentIdentifier,
        in context: ModelContext,
        locale: Locale = .current
    ) throws -> [HorseHistoryEntry] {
        guard context.model(for: horseID) as? Horse != nil else {
            throw HorseHistoryLoadError.horseUnavailable
        }

        let memberships = try context.fetch(FetchDescriptor<VisitHorse>())
        let records = try memberships.compactMap { membership -> HorseHistoryRecord? in
            guard let horse = membership.horse, let visit = membership.visit else {
                throw HorseHistoryLoadError.invalidHistory
            }
            guard horse.persistentModelID == horseID else { return nil }
            let detail = try VisitDetailModel.loadDetail(
                visitID: visit.persistentModelID,
                in: context,
                locale: locale
            )
            guard let result = detail.horses.first(where: { $0.id == membership.persistentModelID }) else {
                throw HorseHistoryLoadError.invalidHistory
            }
            return HorseHistoryRecord(
                id: result.id,
                visitID: detail.visitID,
                horseID: result.horseID,
                horseName: result.horseName,
                startedAt: detail.startedAt,
                completedAt: detail.completedAt,
                serviceLocationName: detail.serviceLocationNameSnapshot,
                outcomeRawValue: result.outcome.rawValue,
                workNotes: result.workNotes,
                workItemCount: result.outcome == .serviced ? result.workItems.count : nil,
                subtotal: result.subtotal
            )
        }
        return try HorseHistoryRules.entries(from: records, locale: locale)
    }

    private func loadHistory() {
        guard let historyHorseID, let historyContext else {
            historyLoadState = .failed
            return
        }

        historyLoadState = .loading
        do {
            let loadingContext = ModelContext(historyContext.container)
            history = try historyLoading(historyHorseID, loadingContext, historyLocale)
            historyLoadState = .loaded
        } catch {
            historyLoadState = .failed
            Self.logger.error("Failed to load horse history: \(error, privacy: .public)")
        }
    }
}
