import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Service catalog rules")
@MainActor
struct ServiceRulesTests {
    @Test
    func validatesANormalizedNameAndExactUSDPrice() throws {
        let values = try ServiceRules.validated(
            ServiceDraft(name: "  Front Shoes  ", priceInput: "$125.50")
        )

        #expect(values.name == "Front Shoes")
        #expect(values.defaultAmountMinorUnits == 12_550)
        #expect(values.currencyCode == "USD")
    }

    @Test
    func rejectsMissingNameAndInvalidPrice() {
        #expect(throws: ServiceRulesError.nameRequired) {
            _ = try ServiceRules.validated(ServiceDraft(name: " \n", priceInput: "12.00"))
        }
        #expect(throws: ServiceRulesError.invalidPrice) {
            _ = try ServiceRules.validated(ServiceDraft(name: "Trim", priceInput: "12.005"))
        }
    }

    @Test
    func sortsActiveBeforeArchivedThenNameAmountAndIdentity() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let archived = ModelFixtures.makeService(
            name: "A Service",
            defaultAmountMinorUnits: 100,
            isArchived: true,
            in: context
        )
        let higherPrice = ModelFixtures.makeService(
            name: "Trim",
            defaultAmountMinorUnits: 200,
            in: context
        )
        let lowerPrice = ModelFixtures.makeService(
            name: "Trim",
            defaultAmountMinorUnits: 100,
            in: context
        )
        let firstName = ModelFixtures.makeService(name: "Balance", in: context)
        try context.save()

        let sorted = ServiceRules.sorted(
            [archived, higherPrice, lowerPrice, firstName],
            locale: Locale(identifier: "en_US")
        )

        #expect(sorted.map(\.persistentModelID) == [
            firstName.persistentModelID,
            lowerPrice.persistentModelID,
            higherPrice.persistentModelID,
            archived.persistentModelID,
        ])
    }

    @Test
    func activeChoicesExcludeArchivedServicesAndKeepDuplicateNamesDistinct() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let first = ModelFixtures.makeService(name: "Trim", defaultAmountMinorUnits: 10_000, in: context)
        let second = ModelFixtures.makeService(name: "Trim", defaultAmountMinorUnits: 12_500, in: context)
        let archived = ModelFixtures.makeService(name: "Archived", isArchived: true, in: context)
        try context.save()

        let choices = ServiceRules.activeChoices(
            [first, second, archived],
            locale: Locale(identifier: "en_US")
        )

        #expect(choices.map(\.id) == [first.persistentModelID, second.persistentModelID])
        #expect(choices.map(\.name) == ["Trim", "Trim"])
        #expect(choices.map(\.defaultAmountMinorUnits) == [10_000, 12_500])
    }
}
