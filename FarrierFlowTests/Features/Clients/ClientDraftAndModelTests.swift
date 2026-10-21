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
        let analytics = AnalyticsSpy()
        let editor = ClientEditorModel()
        editor.draft = ClientDraft(
            name: "  Alex Carter ",
            phone: " ",
            email: "alex@example.com",
            notes: "\n"
        )

        let id = try #require(editor.save(in: context, analyticsClient: analytics))
        let client = try #require(context.model(for: id) as? Client)
        #expect(client.name == "Alex Carter")
        #expect(client.phone == nil)
        #expect(client.email == "alex@example.com")
        #expect(client.notes == nil)

        let edit = ClientEditorModel(client: client)
        edit.draft.name = "Alex B. Carter"
        #expect(edit.save(in: context, analyticsClient: analytics) == id)
        #expect(client.name == "Alex B. Carter")
        #expect(analytics.events == [.clientCreated])

        let invalid = ClientEditorModel()
        #expect(invalid.save(in: context, analyticsClient: analytics) == nil)
        #expect(analytics.events == [.clientCreated])
    }

    @Test
    func overlappingRemoteEditKeepsTheDraftAndDoesNotWriteAnyFields() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Original", phone: "111")
        container.mainContext.insert(client)
        try container.mainContext.save()
        let model = ClientEditorModel(client: client)
        model.draft.phone = "Local phone"
        model.draft.notes = "Unsaved notes"
        client.phone = "Cloud phone"
        try container.mainContext.save()
        #expect(model.save(in: container.mainContext) == nil)
        #expect(client.phone == "Cloud phone" && client.notes == nil)
        #expect(model.draft.phone == "Local phone" && model.draft.notes == "Unsaved notes")
        #expect(model.alert != nil)
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func failedCreateDoesNotEmitAnalytics() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        context.insert(BusinessProfile(name: "First"))
        context.insert(BusinessProfile(name: "Second"))
        try context.save()
        let analytics = AnalyticsSpy()
        let editor = ClientEditorModel()
        editor.draft.name = "Alex"

        #expect(editor.save(in: context, analyticsClient: analytics) == nil)
        #expect(analytics.events.isEmpty)
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
    func listHorseCountsFollowSavedRelationships() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let first = Client(name: "Arthur")
        let second = Client(name: "John")
        let barn = Barn(name: "North Field")
        context.insert(first)
        context.insert(second)
        context.insert(barn)
        let atlas = Horse(name: "Atlas", client: first, currentBarn: barn)
        let beacon = Horse(name: "Beacon", client: first, currentBarn: barn)
        context.insert(atlas)
        context.insert(beacon)
        first.horses.append(contentsOf: [atlas, beacon])
        barn.horses.append(contentsOf: [atlas, beacon])
        try DomainGraphValidator.save(context)
        let model = ClientListModel()
        model.load(in: ModelContext(container))
        #expect(model.clients.map(\.horseCount) == [2, 0])

        atlas.client = second
        try DomainGraphValidator.save(context)
        model.load(in: ModelContext(container))
        #expect(model.clients.map(\.horseCount) == [1, 1])

        try RecordDeletionRules.delete(beacon, in: context)
        model.load(in: ModelContext(container))
        #expect(model.clients.map(\.horseCount) == [0, 1])
    }

    @Test
    func listReadsSavedCountsAndContactAfterStoreReopens() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClientListReopen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("workspace.store")
        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            let context = container.mainContext
            let client = Client(name: "Arthur", phone: "+13625849")
            let barn = Barn(name: "North Field")
            context.insert(client)
            context.insert(Client(name: "John"))
            context.insert(barn)
            let horses = ["Atlas", "Beacon"].map { name in
                Horse(name: name, client: client, currentBarn: barn)
            }
            for horse in horses { context.insert(horse) }
            client.horses = horses
            barn.horses = horses
            try DomainGraphValidator.save(context)
        }

        let reopened = try ModelContainerFactory.persistentStoreTest(at: url)
        let model = ClientListModel()
        model.load(in: ModelContext(reopened))
        #expect(model.alert == nil)
        #expect(model.clients.map(\.name) == ["Arthur", "John"])
        #expect(model.clients.map(\.phone) == ["+13625849", nil])
        #expect(model.clients.map(\.horseCount) == [2, 0])
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
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: context
        )
        try DomainGraphValidator.save(context)

        model.load(id: client.persistentModelID, in: context)

        #expect(model.hasInvoiceableWork)

        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 2, in: context)
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: client,
            businessProfile: profile,
            in: context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: workItem,
            in: context
        )
        try DomainGraphValidator.save(context)

        model.load(id: client.persistentModelID, in: context)

        #expect(!model.hasInvoiceableWork)
        #expect(model.invoices.map(\.number) == ["0001"])
        #expect(model.invoices.map(\.status) == [.unpaid])
    }
}
