import Foundation
import Observation
import OSLog
import SwiftData

enum BusinessOverviewRoute: Hashable {
    case outstandingInvoices
    case completedVisits(DateInterval)
}

nonisolated struct BusinessOverviewSummary: Equatable {
    let outstandingMinorUnits: Int64
    let unpaidInvoiceCount: Int
    let currencyCode: String
    let completedVisitCount: Int
    let month: DateInterval
}

nonisolated enum BusinessOverviewError: Error {
    case invalidBusinessCurrency
    case unavailableMonth
}

@MainActor
@Observable
final class BusinessOverviewModel {
    private static let logger = Logger(subsystem: "com.farrierflow.yusufcan.FarrierFlow", category: "BusinessOverview")
    private(set) var summary: BusinessOverviewSummary?
    private(set) var loadFailed = false

    func load(in context: ModelContext, now: Date, calendar: Calendar, locale: Locale) {
        do {
            // A fresh read context includes changes saved by detail editors in other contexts.
            let readingContext = ModelContext(context.container)
            var profileDescriptor = FetchDescriptor<BusinessProfile>()
            profileDescriptor.fetchLimit = 2
            let profiles = try readingContext.fetch(profileDescriptor)
            guard profiles.count == 1, let profile = profiles.first,
                  BusinessCurrency.isSupported(profile.currencyCode) else {
                throw BusinessOverviewError.invalidBusinessCurrency
            }
            guard let month = calendar.dateInterval(of: .month, for: now) else {
                throw BusinessOverviewError.unavailableMonth
            }
            let invoices = try readingContext.fetch(FetchDescriptor<Invoice>()).map {
                guard $0.currencyCode == profile.currencyCode else {
                    throw BusinessOverviewError.invalidBusinessCurrency
                }
                return try InvoiceProjection.summary(from: $0, locale: locale)
            }
            let unpaid = invoices.filter { $0.status == .unpaid }
            let amounts = try unpaid.map { invoice in
                guard case .available(let amount) = invoice.total else {
                    throw InvoiceDomainRuleError.invalidStatus
                }
                return amount
            }
            let visits = try CompletedVisitListModel.summaries(in: readingContext, during: month, locale: locale)
            summary = BusinessOverviewSummary(
                outstandingMinorUnits: try CheckedMoneyTotal.sum(amounts),
                unpaidInvoiceCount: unpaid.count,
                currencyCode: profile.currencyCode,
                completedVisitCount: visits.count,
                month: month
            )
            loadFailed = false
        } catch {
            Self.logger.error("Business overview unavailable: \(error, privacy: .public)")
            summary = nil
            loadFailed = true
        }
    }
}
