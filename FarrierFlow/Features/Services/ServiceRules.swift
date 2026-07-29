import Foundation
import SwiftData

nonisolated enum ServiceRulesError: Error, Equatable {
    case nameRequired
    case invalidPrice
}

nonisolated enum ServiceRules {
    static func validated(_ draft: ServiceDraft) throws -> ServiceValues {
        guard let name = TextNormalization.required(draft.name) else {
            throw ServiceRulesError.nameRequired
        }
        guard let amount = try? USDPriceParser.parse(draft.priceInput) else {
            throw ServiceRulesError.invalidPrice
        }
        return ServiceValues(
            name: name,
            defaultAmountMinorUnits: amount,
            currencyCode: "USD"
        )
    }

    @MainActor
    static func sorted(_ services: [Service], locale: Locale = .current) -> [Service] {
        services.sorted { left, right in
            if left.isArchived != right.isArchived {
                return !left.isArchived
            }

            let nameOrder = left.name.compare(
                right.name,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric],
                locale: locale
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            if left.defaultAmountMinorUnits != right.defaultAmountMinorUnits {
                return left.defaultAmountMinorUnits < right.defaultAmountMinorUnits
            }
            return String(describing: left.persistentModelID)
                < String(describing: right.persistentModelID)
        }
    }

    @MainActor
    static func activeChoices(_ services: [Service], locale: Locale = .current) -> [ServiceChoice] {
        sorted(services.filter { !$0.isArchived }, locale: locale).map { service in
            ServiceChoice(
                id: service.persistentModelID,
                name: service.name,
                defaultAmountMinorUnits: service.defaultAmountMinorUnits,
                currencyCode: service.currencyCode
            )
        }
    }
}
