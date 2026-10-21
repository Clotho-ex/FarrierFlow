import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Deletion display safety")
@MainActor
struct DeletionSnapshotTests {
    @Test
    func loadingDeletedServiceDoesNotExposeAnInvalidModel() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let service = ModelFixtures.makeService(in: context)
        try context.save()
        let id = service.persistentModelID
        try RecordDeletionRules.delete(service, in: context)

        let model = ServiceDetailModel()
        model.load(id: id, in: ModelContext(container))

        let isUnavailable = model.service == nil
        #expect(isUnavailable)
    }

    @Test
    func failedPersistenceRestoresServiceAndKeepsUsefulError() throws {
        let graph = try Graph()
        let model = ServiceDetailModel()
        model.load(id: graph.service.persistentModelID, in: ModelContext(graph.container))
        let action = ModelContext(graph.container)
        action.insert(BusinessProfile(name: "Conflicting profile one"))
        action.insert(BusinessProfile(name: "Conflicting profile two"))

        #expect(!model.delete(in: action))
        #expect(model.service?.name == "Trim")
        #expect(model.alert?.message == "The service wasn’t deleted. Try again.")
        #expect(try ModelContext(graph.container).fetchCount(FetchDescriptor<Service>()) == 1)
        try DomainGraphValidator.validateAll(in: ModelContext(graph.container))
    }

    @Test
    func serviceDisplayAndCachedRowsSurviveReentrantSaveAndFailure() throws {
        let graph = try Graph()
        let model = ServiceDetailModel()
        model.load(id: graph.service.persistentModelID, in: ModelContext(graph.container))
        let list = ServiceListModel()
        list.load(in: ModelContext(graph.container))
        let retained = try #require(model.service)
        let action = ModelContext(graph.container)

        #expect(!model.delete(in: action) { _, _ in throw SaveFailure.failed })
        #expect(model.service == retained)
        #expect(model.alert?.title == "Couldn’t Delete Service")
        let deleted = model.delete(in: action) { record, context in
            #expect(record.modelContext === context)
            try RecordDeletionRules.delete(record, in: context)
            #expect(model.service?.name == "Trim")
            #expect(list.activeServices.map(\.name) == ["Trim"])
        }
        #expect(deleted)
        #expect(retained.name == "Trim")
        #expect(model.service == nil)
    }

    @Test
    func clientDisplayAndCachedRowsSurviveReentrantSaveAndFailure() throws {
        let graph = try Graph()
        try RecordDeletionRules.delete(graph.horse, in: graph.container.mainContext)
        let model = ClientDetailModel()
        model.load(id: graph.client.persistentModelID, in: ModelContext(graph.container))
        let list = ClientListModel()
        list.load(in: ModelContext(graph.container))
        let retainedRow = try #require(list.clients.first)
        let retained = try #require(model.client)
        let action = ModelContext(graph.container)

        #expect(!model.delete(in: action) { _, _ in throw SaveFailure.failed })
        #expect(model.client == retained)
        #expect(model.alert?.title == "Couldn’t Delete Client")
        let deleted = model.delete(in: action) { record, context in
            #expect(record.modelContext === context)
            try RecordDeletionRules.delete(record, in: context)
            #expect(model.client?.name == "Alex")
            #expect(list.clients.map(\.name) == ["Alex"])
        }
        #expect(deleted)
        #expect(retained.name == "Alex")
        #expect(retainedRow.name == "Alex")
        #expect(retainedRow.horseCount == 0)
        #expect(model.client == nil)
        list.load(in: ModelContext(graph.container))
        #expect(list.clients.isEmpty)
    }

    @Test
    func locationDisplayAndCachedRowsSurviveReentrantSaveAndFailure() throws {
        let graph = try Graph()
        try RecordDeletionRules.delete(graph.horse, in: graph.container.mainContext)
        let model = BarnDetailModel()
        model.load(id: graph.barn.persistentModelID, in: ModelContext(graph.container))
        let list = BarnListModel()
        list.load(in: ModelContext(graph.container))
        let retained = try #require(model.barn)
        let action = ModelContext(graph.container)

        #expect(!model.delete(in: action) { _, _ in throw SaveFailure.failed })
        #expect(model.barn == retained)
        #expect(model.alert?.title == "Couldn’t Delete Service Location")
        let deleted = model.delete(in: action) { record, context in
            #expect(record.modelContext === context)
            try RecordDeletionRules.delete(record, in: context)
            #expect(model.barn?.name == "North Field")
            #expect(list.barns.map(\.name) == ["North Field"])
        }
        #expect(deleted)
        #expect(retained.name == "North Field")
        #expect(model.barn == nil)
    }

    @Test
    func horseDisplayAndRelatedRowsSurviveReentrantSaveAndFailure() throws {
        let graph = try Graph()
        let model = HorseDetailModel()
        model.load(id: graph.horse.persistentModelID, in: ModelContext(graph.container))
        let client = ClientDetailModel()
        client.load(id: graph.client.persistentModelID, in: ModelContext(graph.container))
        let barn = BarnDetailModel()
        barn.load(id: graph.barn.persistentModelID, in: ModelContext(graph.container))
        let retained = try #require(model.horse)
        let action = ModelContext(graph.container)

        #expect(!model.delete(in: action) { _, _ in throw SaveFailure.failed })
        #expect(model.horse == retained)
        #expect(model.alert?.title == "Couldn’t Delete Horse")
        let deleted = model.delete(in: action) { record, context in
            #expect(record.modelContext === context)
            try RecordDeletionRules.delete(record, in: context)
            #expect(model.horse?.name == "Milo")
            #expect(client.client?.horses.first?.name == "Milo")
            #expect(barn.barn?.horses.first?.name == "Milo")
        }
        #expect(deleted)
        #expect(retained.client?.name == "Alex")
        #expect(retained.currentBarn?.name == "North Field")
        #expect(model.horse == nil)
    }

    @Test
    func deletedElsewhereProducesUsefulErrorsAndNeverExposesFaults() throws {
        let graph = try Graph()
        let service = ServiceDetailModel()
        let client = ClientDetailModel()
        let barn = BarnDetailModel()
        let horse = HorseDetailModel()
        let ids = (graph.service.persistentModelID, graph.client.persistentModelID,
                   graph.barn.persistentModelID, graph.horse.persistentModelID)
        service.load(id: ids.0, in: ModelContext(graph.container))
        client.load(id: ids.1, in: ModelContext(graph.container))
        barn.load(id: ids.2, in: ModelContext(graph.container))
        horse.load(id: ids.3, in: ModelContext(graph.container))
        let context = graph.container.mainContext
        try RecordDeletionRules.delete(graph.horse, in: context)
        try RecordDeletionRules.delete(graph.client, in: context)
        try RecordDeletionRules.delete(graph.barn, in: context)
        try RecordDeletionRules.delete(graph.service, in: context)

        #expect(!service.delete(in: ModelContext(graph.container)))
        #expect(service.alert?.message == "This service is no longer available.")
        #expect(!service.archive(in: ModelContext(graph.container)))
        #expect(!service.reactivate(in: ModelContext(graph.container)))
        #expect(!client.delete(in: ModelContext(graph.container)))
        #expect(client.alert?.message == "This client is no longer available.")
        #expect(!barn.delete(in: ModelContext(graph.container)))
        #expect(barn.alert?.message == "This service location is no longer available.")
        #expect(!horse.delete(in: ModelContext(graph.container)))
        #expect(horse.alert?.message == "This horse is no longer available.")
        #expect(client.client?.horses.first?.client?.name == "Alex")

        service.load(id: ids.0, in: ModelContext(graph.container))
        client.load(id: ids.1, in: ModelContext(graph.container))
        barn.load(id: ids.2, in: ModelContext(graph.container))
        horse.load(id: ids.3, in: ModelContext(graph.container))
        #expect(service.service == nil)
        #expect(client.client == nil)
        #expect(barn.barn == nil)
        #expect(horse.horse == nil)
    }

    @Test
    func freshActionsSeeReferencesCreatedAfterDisplayLoaded() throws {
        let graph = try Graph()
        let model = ServiceDetailModel()
        model.load(id: graph.service.persistentModelID, in: ModelContext(graph.container))
        let client = ClientDetailModel()
        client.load(id: graph.client.persistentModelID, in: ModelContext(graph.container))
        let barn = BarnDetailModel()
        barn.load(id: graph.barn.persistentModelID, in: ModelContext(graph.container))
        let horse = HorseDetailModel()
        horse.load(id: graph.horse.persistentModelID, in: ModelContext(graph.container))
        graph.horse.defaultService = graph.service
        _ = ModelFixtures.makeAppointment(barn: graph.barn, horses: [graph.horse], in: graph.container.mainContext)
        try DomainGraphValidator.save(graph.container.mainContext)

        #expect(model.delete(in: ModelContext(graph.container)))
        #expect(model.alert == nil)
        #expect(horse.delete(in: ModelContext(graph.container)))
        #expect(horse.alert == nil)
        #expect(client.delete(in: ModelContext(graph.container)))
        #expect(client.alert == nil)
        #expect(barn.delete(in: ModelContext(graph.container)))
        #expect(barn.alert == nil)
        try DomainGraphValidator.validateAll(in: ModelContext(graph.container))
    }

    @Test
    func editorsKeepDraftsAndExplainRecordsDeletedElsewhere() throws {
        let graph = try Graph()
        _ = ModelFixtures.makeBusinessProfile(in: graph.container.mainContext)
        try graph.container.mainContext.save()
        let service = ServiceEditorModel(service: graph.service)
        let client = ClientEditorModel(client: graph.client)
        let barn = BarnEditorModel(barn: graph.barn)
        let horse = HorseEditorModel(horse: graph.horse)
        try RecordDeletionRules.delete(graph.horse, in: graph.container.mainContext)
        #expect(horse.save(in: ModelContext(graph.container)) == nil)
        #expect(horse.alert?.message == "This horse is no longer available.")
        try RecordDeletionRules.delete(graph.client, in: graph.container.mainContext)
        try RecordDeletionRules.delete(graph.barn, in: graph.container.mainContext)
        try RecordDeletionRules.delete(graph.service, in: graph.container.mainContext)
        #expect(service.save(in: ModelContext(graph.container)) == nil)
        #expect(service.alert?.message == "This service is no longer available.")
        #expect(client.save(in: ModelContext(graph.container)) == nil)
        #expect(client.alert?.message == "This client is no longer available.")
        #expect(barn.save(in: ModelContext(graph.container)) == nil)
        #expect(barn.alert?.message == "This service location is no longer available.")
        #expect(horse.save(in: ModelContext(graph.container)) == nil)
        #expect(horse.alert?.title == "Horse Details Unavailable")
        #expect(service.draft.name == "Trim")
        #expect(client.draft.name == "Alex")
        #expect(barn.draft.name == "North Field")
        #expect(horse.draft.name == "Milo")
    }

    private enum SaveFailure: Error { case failed }

    @Test
    func pickerChoicesRemainReadableAndStaleRelocationShowsAnError() throws {
        let graph = try Graph()
        let destination = Barn(name: "Other Stable")
        graph.container.mainContext.insert(destination)
        try graph.container.mainContext.save()
        let destinationID = destination.persistentModelID
        let editor = HorseEditorModel(horse: graph.horse)
        editor.loadChoices(in: ModelContext(graph.container))
        let picker = ExistingHorsePickerModel()
        picker.load(destinationBarnID: destinationID, in: ModelContext(graph.container))
        picker.selectedHorseID = graph.horse.persistentModelID
        try RecordDeletionRules.delete(graph.horse, in: graph.container.mainContext)
        try RecordDeletionRules.delete(graph.client, in: graph.container.mainContext)
        try RecordDeletionRules.delete(graph.barn, in: graph.container.mainContext)

        #expect(editor.clients.first?.name == "Alex")
        #expect(editor.barns.first?.name == "North Field")
        #expect(picker.horses.first?.name == "Milo")
        #expect(!picker.move(to: destinationID, in: ModelContext(graph.container)))
        #expect(picker.alert?.message == "The horse or service location is no longer available. Choose another before moving.")
    }

    @MainActor
    private struct Graph {
        let container: ModelContainer
        let client: Client
        let barn: Barn
        let horse: Horse
        let service: Service

        init() throws {
            container = try ModelContainerFactory.inMemoryTest()
            client = Client(name: "Alex")
            barn = Barn(name: "North Field")
            horse = Horse(name: "Milo", client: client, currentBarn: barn)
            service = Service(name: "Trim", defaultAmountMinorUnits: 5_000)
            let context = container.mainContext
            context.insert(client)
            context.insert(barn)
            context.insert(horse)
            context.insert(service)
            client.horses.append(horse)
            barn.horses.append(horse)
            try DomainGraphValidator.save(context)
        }
    }
}
