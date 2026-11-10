import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Distinct visit workflow states", .serialized)
@MainActor
struct VisitWorkflowStateTests {
    @Test
    func startingAPlannedVisitDoesNotRecordOrBillThePlan() throws {
        let graph = try makeGraph(planned: true)
        let context = ModelContext(graph.container)
        #expect(try context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
        let visit = try #require(try context.existingModel(Visit.self, for: graph.visitID))
        #expect(visit.visitHorses.first?.outcomeRawValue == VisitOutcome.pending.rawValue)
        #expect(visit.appointment?.appointmentHorses.first?.plannedService?.persistentModelID == graph.serviceID)
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let horse = try #require(model.draft?.horses.first)
        _ = model.requestOutcomeChange(for: horse.id, to: .serviced)
        #expect(model.draft?.horses.first?.workItems.isEmpty == true)
        #expect(!model.canComplete)
    }

    @Test
    func unresolvedHorseNotesSaveWithoutCompletingAndSurviveReload() throws {
        let graph = try makeGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let horse = try #require(model.draft?.horses.first)
        model.setWorkNotes("Waiting for the owner.\n\nReturn through the west gate.", for: horse.id)
        #expect(model.isDirty)
        try #require(model.saveProgress())
        #expect(!model.isDirty)
        let reloaded = try VisitSaveUseCase.loadDraft(visitID: graph.visitID, in: ModelContext(graph.container))
        #expect(reloaded.horses.first?.outcome == .pending)
        #expect(reloaded.horses.first?.workNotes.contains("west gate") == true)
        _ = try VisitDetailModel.loadDetail(visitID: graph.visitID, in: ModelContext(graph.container))
        #expect(try ModelContext(graph.container).existingModel(Visit.self, for: graph.visitID)?.completedAt == nil)
    }

    @Test
    func notServicedRetainsConflictingWorkUntilExplicitRemoval() throws {
        let graph = try makeGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let horse = try #require(model.draft?.horses.first)
        try #require(model.addService(graph.serviceID, to: horse.id))
        model.setWorkNotes("Horse could not be handled safely.", for: horse.id)
        _ = model.requestOutcomeChange(for: horse.id, to: .notServiced)
        #expect(model.draft?.horses.first?.outcome == .notServiced)
        #expect(model.draft?.horses.first?.workItems.count == 1)
        #expect(model.draft?.horses.first?.workNotes == "Horse could not be handled safely.")
        #expect(model.completionBlocker == .notServicedHorseHasWorkItems)
        try #require(model.saveProgress())
        #expect(!model.canComplete)
        let savedDetail = try VisitDetailModel.loadDetail(visitID: graph.visitID, in: ModelContext(graph.container))
        #expect(savedDetail.horses.first?.workItems.count == 1)
        let work = try #require(model.draft?.horses.first?.workItems.first)
        try #require(model.removeWorkItem(work.id, from: horse.id))
        #expect(model.canComplete)
        try #require(model.completeVisit(at: Date(timeIntervalSinceReferenceDate: 200)))
        let context = ModelContext(graph.container)
        let visit = try #require(try context.existingModel(Visit.self, for: graph.visitID))
        #expect(visit.visitHorses.first?.workNotes == "Horse could not be handled safely.")
        #expect(try context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
        try DomainGraphValidator.validateAll(in: context)
    }

    @Test
    func attendanceWithoutPerformedServicesCanBeCompletedWithAReason() throws {
        let graph = try makeGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let horse = try #require(model.draft?.horses.first)
        _ = model.requestOutcomeChange(for: horse.id, to: .notServiced)
        model.setWorkNotes("Owner unavailable.", for: horse.id)
        #expect(model.canComplete)
        try #require(model.saveProgress())
        #expect(model.canComplete)
        #expect(try ModelContext(graph.container).existingModel(Visit.self, for: graph.visitID)?.completedAt == nil)
        try #require(model.completeVisit(at: Date(timeIntervalSinceReferenceDate: 200)))
        let context = ModelContext(graph.container)
        #expect(try context.existingModel(Visit.self, for: graph.visitID)?.completedAt != nil)
        #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 0)
        let detail = try VisitDetailModel.loadDetail(visitID: graph.visitID, in: context)
        #expect(detail.horses.first?.workNotes == "Owner unavailable.")
        #expect(try CompletedVisitListModel.summaries(in: context, locale: Locale(identifier: "en_US")).count == 1)
    }

    @Test
    func performedDraftTotalChangesImmediatelyWithoutChangingCatalogPrice() throws {
        let graph = try makeGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let horse = try #require(model.draft?.horses.first)
        try #require(model.addService(graph.serviceID, to: horse.id))
        #expect(model.draft?.recordedTotal == .available(minorUnits: 10_000, currencyCode: "USD"))
        let work = try #require(model.draft?.horses.first?.workItems.first)
        try #require(model.updateWorkItem(work.id, serviceID: graph.serviceID, priceInput: "225.00",
            for: horse.id, locale: Locale(identifier: "en_US")))
        #expect(model.draft?.recordedTotal == .available(minorUnits: 22_500, currencyCode: "USD"))
        #expect(model.savedRecordedTotal == .none)
        #expect(try ModelContext(graph.container).existingModel(Service.self, for: graph.serviceID)?.defaultAmountMinorUnits == 10_000)
        try #require(model.removeWorkItem(work.id, from: horse.id))
        #expect(model.draft?.recordedTotal == VisitRecordedTotal.none)
    }

    @Test
    func confirmingAPlanRecordsWorkOnceWithoutChangingTheAppointmentPlan() throws {
        let graph = try makeGraph(planned: true)
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let horse = try #require(model.draft?.horses.first)
        #expect(horse.plannedService?.id == graph.serviceID)
        try #require(model.confirmPlannedService(for: horse.id))
        #expect(!model.confirmPlannedService(for: horse.id))
        #expect(model.draft?.horses.first?.outcome == .pending)
        #expect(model.draft?.horses.first?.workItems.count == 1)
        try #require(model.saveProgress())
        let context = ModelContext(graph.container)
        let visit = try #require(try context.existingModel(Visit.self, for: graph.visitID))
        #expect(visit.completedAt == nil)
        #expect(visit.appointment?.appointmentHorses.first?.plannedService?.persistentModelID == graph.serviceID)
    }

    @Test
    func invoiceUsesExplicitlyPerformedVisitPriceAndSyncPreservesUnresolvedNotes() throws {
        let graph = try makeGraph(planned: true)
        let context = ModelContext(graph.container)
        _ = ModelFixtures.makeBusinessProfile(in: context)
        try DomainGraphValidator.save(context)
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let horse = try #require(model.draft?.horses.first)
        model.setWorkNotes("Owner unavailable; return later.", for: horse.id)
        try #require(model.saveProgress())
        try assertSyncRoundTrip(graph.container)
        try #require(model.confirmPlannedService(for: horse.id))
        let work = try #require(model.draft?.horses.first?.workItems.first)
        try #require(model.updateWorkItem(work.id, serviceID: graph.serviceID, priceInput: "225.00",
            for: horse.id, locale: Locale(identifier: "en_US")))
        _ = model.requestOutcomeChange(for: horse.id, to: .notServiced)
        try #require(model.saveProgress())
        try assertSyncRoundTrip(graph.container)
        _ = model.requestOutcomeChange(for: horse.id, to: .serviced)
        try #require(model.completeVisit(at: Date(timeIntervalSinceReferenceDate: 200)))
        let billing = ModelContext(graph.container)
        let visit = try #require(try billing.existingModel(Visit.self, for: graph.visitID))
        let clientID = try #require(visit.visitHorses.first?.horse?.client?.persistentModelID)
        let invoiceID = try InvoiceGenerationUseCase.generate(InvoiceCreationDraft(
            clientID: clientID, selectedVisitIDs: [graph.visitID],
            invoiceDate: Date(timeIntervalSinceReferenceDate: 300), dueDate: nil, note: ""
        ), in: billing)
        let invoice = try #require(try billing.existingModel(Invoice.self, for: invoiceID))
        #expect(invoice.invoiceVisits.flatMap(\.lineItems).map(\.amountMinorUnits) == [22_500])
        #expect(visit.appointment?.appointmentHorses.first?.plannedService?.defaultAmountMinorUnits == 10_000)
        try assertSyncRoundTrip(graph.container)
    }

    private func assertSyncRoundTrip(_ source: ModelContainer) throws {
        let records = try SyncGraphCodec.capture(in: ModelContext(source))
        let destination = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(records, in: destination.mainContext)
        #expect(try SyncGraphCodec.capture(in: destination.mainContext) == records)
    }

    private func makeGraph(planned: Bool = false) throws -> (
        container: ModelContainer, visitID: PersistentIdentifier, serviceID: PersistentIdentifier
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Jeremy Clarkson")
        let barn = Barn(name: "The Clarkson Farm")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Burger", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let service = ModelFixtures.makeService(name: "Brushing", defaultAmountMinorUnits: 10_000, in: context)
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        if planned {
            appointment.appointmentHorses.first?.plannedService = service
            horse.defaultService = service
        }
        try DomainGraphValidator.save(context)
        let visitID = try VisitStartUseCase.start(appointmentID: appointment.persistentModelID,
            now: Date(timeIntervalSinceReferenceDate: 100), in: container)
        return (container, visitID, service.persistentModelID)
    }
}
