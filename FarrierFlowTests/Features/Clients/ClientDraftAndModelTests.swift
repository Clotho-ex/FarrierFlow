import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Client drafts and models")
@MainActor
struct ClientDraftAndModelTests {
    @Test
    func draftRequiresTrimmedNameOnly() {
        #expect(!ClientDraft(name: "  ").isValid)
        #expect(ClientDraft(name: " Alex ", phone: "not formatted").isValid)
    }

    @Test
    func createNormalizesFieldsAndEditPreservesIdentity() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let editor = ClientEditorModel()
        editor.draft = ClientDraft(
            name: "  Alex Carter ",
            phone: " ",
            email: "alex@example.com",
            notes: "\n"
        )

        let id = try #require(
            editor.save(in: context, coordinator: PersistenceMutationCoordinator())
        )
        let client = try #require(context.model(for: id) as? Client)
        #expect(client.name == "Alex Carter")
        #expect(client.phone == nil)
        #expect(client.email == "alex@example.com")
        #expect(client.notes == nil)

        let edit = ClientEditorModel(client: client)
        edit.draft.name = "Alex B. Carter"
        #expect(
            edit.save(in: context, coordinator: PersistenceMutationCoordinator()) == id
        )
        #expect(client.name == "Alex B. Carter")
    }

    @Test
    func listLoadsAlphabetically() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        context.insert(Client(name: "Zoe"))
        context.insert(Client(name: "Alex"))
        try context.save()

        let model = ClientListModel()
        model.load(in: context)
        #expect(model.clients.map(\.name) == ["Alex", "Zoe"])
    }

    @Test
    func detailDeletionInvalidatesAnActiveReadGeneration() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        context.insert(client)
        try context.save()
        let model = ClientDetailModel()
        model.load(id: client.persistentModelID, in: context)
        let coordinator = PersistenceMutationCoordinator()
        let generation = try coordinator.beginRead()

        #expect(model.delete(in: context, coordinator: coordinator))
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 0)
        #expect(throws: PersistenceMutationCoordinatorError.sourceChanged) {
            try coordinator.validate(generation)
        }
    }

    @Test
    func detailOnlyOffersAnInvoiceForCompletedUninvoicedWork() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        let model = ClientDetailModel()

        model.load(id: client.persistentModelID, in: context)

        #expect(!model.hasInvoiceableWork)

        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(in: context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: context
        )
        try DomainGraphValidator.save(context)

        model.load(id: client.persistentModelID, in: context)

        #expect(model.hasInvoiceableWork)
    }
}
