import Foundation
import SwiftData

nonisolated enum InvoiceDomainRuleError: Error, Equatable {
    case invalidNumber
    case invalidStatus
}

@MainActor
enum InvoiceDomainRules {
    static func validatedStatus(
        rawValue: String,
        paidAt: Date?
    ) throws -> InvoiceStatus {
        guard let status = InvoiceStatus(rawValue: rawValue) else {
            throw InvoiceDomainRuleError.invalidStatus
        }
        switch (status, paidAt) {
        case (.unpaid, nil), (.paid, .some):
            return status
        case (.unpaid, .some), (.paid, nil):
            throw InvoiceDomainRuleError.invalidStatus
        }
    }

    static func formattedNumber(_ number: Int64) throws -> String {
        guard number > 0 else {
            throw InvoiceDomainRuleError.invalidNumber
        }
        return String(format: "%04lld", number)
    }

    static func checkedTotal(_ amounts: [Int64]) throws -> Int64 {
        try CheckedMoneyTotal.sum(amounts)
    }

    static func isCorrectionLocked(_ visit: Visit) -> Bool {
        visit.visitHorses.contains { visitHorse in
            visitHorse.workItems.contains { $0.invoiceLineItem != nil }
        }
    }

    static func orderedVisits(
        _ visits: [InvoiceVisit],
        locale: Locale
    ) -> [InvoiceVisit] {
        visits.sorted { left, right in
            if left.visitDateSnapshot != right.visitDateSnapshot {
                return left.visitDateSnapshot < right.visitDateSnapshot
            }
            let nameOrder = localizedOrder(
                left.serviceLocationNameSnapshot,
                right.serviceLocationNameSnapshot,
                locale: locale
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return String(describing: left.persistentModelID)
                < String(describing: right.persistentModelID)
        }
    }

    static func orderedLineItems(
        _ lineItems: [InvoiceLineItem],
        locale: Locale
    ) -> [InvoiceLineItem] {
        lineItems.sorted { left, right in
            let horseOrder = localizedOrder(
                left.horseNameSnapshot,
                right.horseNameSnapshot,
                locale: locale
            )
            if horseOrder != .orderedSame {
                return horseOrder == .orderedAscending
            }
            let serviceOrder = localizedOrder(
                left.serviceNameSnapshot,
                right.serviceNameSnapshot,
                locale: locale
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

    private static func localizedOrder(
        _ left: String,
        _ right: String,
        locale: Locale
    ) -> ComparisonResult {
        left.compare(
            right,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric],
            range: nil,
            locale: locale
        )
    }
}
