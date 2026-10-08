import Foundation
import SwiftData

nonisolated enum ServiceRulesError: Error, Equatable {
    case nameRequired
    case invalidPrice
    case unsupportedCurrency
}

nonisolated enum ServiceRules {
    static func validated(
        _ draft: ServiceDraft,
        locale: Locale = .current
    ) throws -> ServiceValues {
        guard let name = TextNormalization.required(draft.name) else {
            throw ServiceRulesError.nameRequired
        }
        let currencyCode = draft.currencyCode.uppercased()
        guard BusinessCurrency.isSupported(currencyCode) else {
            throw ServiceRulesError.unsupportedCurrency
        }
        guard let amount = try? MoneyInputParser.parse(
            draft.priceInput,
            currencyCode: currencyCode,
            locale: locale
        ) else {
            throw ServiceRulesError.invalidPrice
        }
        return ServiceValues(
            name: name,
            defaultAmountMinorUnits: amount,
            currencyCode: currencyCode
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
        sorted(services.filter(isEligibleForFutureSelection), locale: locale).map { service in
            ServiceChoice(
                id: service.persistentModelID,
                name: service.name,
                defaultAmountMinorUnits: service.defaultAmountMinorUnits,
                currencyCode: service.currencyCode
            )
        }
    }

    @MainActor
    private static func isEligibleForFutureSelection(_ service: Service) -> Bool {
        !service.isArchived
            && TextNormalization.required(service.name) == service.name
            && service.defaultAmountMinorUnits >= 0
            && BusinessCurrency.isSupported(service.currencyCode)
            && service.horsesUsingAsDefault.allSatisfy { $0.defaultService === service }
            && service.workItems.allSatisfy { $0.service === service }
    }
}
