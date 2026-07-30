import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Service editor model")
@MainActor
struct ServiceEditorModelTests {
    @Test
    func createsNormalizedUSDServiceIncludingComplimentaryPrice() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let model = ServiceEditorModel()
        model.draft = ServiceDraft(name: "  Hoof Trim ", priceInput: "0")

        let id = try #require(model.save(in: context))
        let service = try #require(context.model(for: id) as? Service)
        #expect(service.name == "Hoof Trim")
        #expect(service.defaultAmountMinorUnits == 0)
        #expect(service.currencyCode == "USD")
        #expect(!service.isArchived)
    }

    @Test
    func editChangesCatalogValuesWithoutRewritingWorkItemSnapshots() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        let visit = ModelFixtures.makeVisit(
            completedAt: .now,
            appointment: appointment,
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(name: "Front Shoes", in: context)
        let workItem = ModelFixtures.makeWorkItem(service: service, visitHorse: visitHorse, in: context)
        try DomainGraphValidator.save(context)

        let model = ServiceEditorModel(service: service)
        model.draft = ServiceDraft(name: "Front Shoes and Pads", priceInput: "150.00")
        #expect(model.save(in: context) == service.persistentModelID)
        #expect(service.name == "Front Shoes and Pads")
        #expect(service.defaultAmountMinorUnits == 15_000)
        #expect(workItem.serviceNameSnapshot == "Front Shoes")
        #expect(workItem.amountMinorUnits == 12_500)
        #expect(workItem.currencyCode == "USD")
    }
}
