import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Linked work visibility")
@MainActor
struct RecordUsageSnapshotTests {
    @Test
    func serviceShowsTheExactBilledVisitWithoutDuplicatingItsHorses() throws {
        let graph = try makeGraph(completed: true)
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 43, in: graph.context)
        let invoice = ModelFixtures.makeInvoice(number: 42, client: graph.client, businessProfile: profile, in: graph.context)
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(invoice: invoice, sourceVisit: graph.visit, in: graph.context)
        for membership in graph.visit.visitHorses {
            for work in membership.workItems {
                _ = try ModelFixtures.makeInvoiceLineItem(invoiceVisit: invoiceVisit, sourceWorkItem: work, in: graph.context)
            }
        }
        try DomainGraphValidator.save(graph.context)

        let model = ServiceDetailModel()
        model.load(id: graph.service.persistentModelID, in: graph.context)
        let visit = try #require(model.usage.visits.first)
        #expect(model.usage.visits.count == 1)
        #expect(visit.id == graph.visit.persistentModelID)
        #expect(visit.location == "Restore Barn")
        #expect(visit.horseNames == ["Milo", "Scout"])
        #expect(visit.serviceNames == ["Trim", "Trim"])
        #expect(visit.invoiceNumbers == ["0042"])
        #expect(visit.isCompleted)
        #expect(model.delete(in: graph.context))
        #expect(try graph.context.fetchCount(FetchDescriptor<Invoice>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
        #expect(invoice.invoiceVisits.first?.lineItems.count == 2)
        #expect(invoice.invoiceVisits.first?.lineItems.allSatisfy { $0.sourceWorkItem == nil } == true)
        try DomainGraphValidator.validateAll(in: graph.context)
    }

    @Test
    func horseShowsUnfinishedVisitsThatCompletedHistoryExcludes() throws {
        let graph = try makeGraph(completed: false)
        let model = HorseDetailModel()
        let horse = try #require(graph.visit.visitHorses.first?.horse)
        model.load(id: horse.persistentModelID, in: graph.context)
        #expect(model.history.isEmpty)
        #expect(model.inProgressVisits.map(\.id) == [graph.visit.persistentModelID])
        #expect(model.inProgressVisits.first?.serviceNames == ["Trim"])
        let horseID = horse.persistentModelID
        #expect(model.delete(in: graph.context))
        #expect(try graph.context.existingModel(Horse.self, for: horseID) == nil)
        #expect(graph.visit.visitHorses.count == 1)
        try DomainGraphValidator.validateAll(in: graph.context)
    }

    @Test
    func unstartedAppointmentsRemainVisibleEvenWhenOverdueAndReloadAfterEditing() throws {
        let graph = try makeGraph(completed: true)
        let horse = try #require(graph.visit.visitHorses.first?.horse)
        let barn = try #require(horse.currentBarn)
        let appointment = ModelFixtures.makeAppointment(
            startDate: Date(timeIntervalSinceReferenceDate: 10), barn: barn, horses: [horse], in: graph.context
        )
        appointment.appointmentHorses.first?.plannedService = graph.service
        try DomainGraphValidator.save(graph.context)
        let model = HorseDetailModel()
        model.load(id: horse.persistentModelID, in: graph.context)
        #expect(model.usage.appointments.map(\.id) == [appointment.persistentModelID])
        #expect(model.inProgressVisits.isEmpty)
        #expect(model.history.count == 1)

        let newDate = Date(timeIntervalSinceReferenceDate: 20)
        appointment.startDate = newDate
        try DomainGraphValidator.save(graph.context)
        model.load(id: horse.persistentModelID, in: ModelContext(graph.container))
        #expect(model.usage.appointments.first?.startDate == newDate)
        #expect(model.usage.appointments.first?.id == appointment.persistentModelID)
    }

    @Test
    func plannedServiceIsVisibleAfterVisitStartsBeforeWorkIsRecorded() throws {
        let graph = try makeGraph(completed: false)
        for membership in graph.visit.visitHorses {
            for work in membership.workItems {
                try RecordDeletionRules.delete(work, in: graph.context)
            }
            membership.outcomeRawValue = VisitOutcome.pending.rawValue
        }
        let appointment = try #require(graph.visit.appointment)
        appointment.appointmentHorses.first?.plannedService = graph.service
        try DomainGraphValidator.save(graph.context)
        let usage = try RecordUsageSnapshot(service: graph.service)
        #expect(usage.appointments.map(\.id) == [appointment.persistentModelID])
        #expect(usage.visits.isEmpty)
    }

    @Test
    func copiedUsageDoesNotChangeWhenLiveRecordsAreEdited() throws {
        let graph = try makeGraph(completed: true)
        let usage = try RecordUsageSnapshot(service: graph.service)
        graph.visit.serviceLocationNameSnapshot = "Changed Barn"
        graph.visit.visitHorses.first?.workItems.first?.serviceNameSnapshot = "Changed Work"
        #expect(usage.visits.first?.location == "Restore Barn")
        #expect(usage.visits.first?.serviceNames == ["Trim", "Trim"])
    }

    private func makeGraph(completed: Bool) throws -> (
        container: ModelContainer, context: ModelContext, client: Client, service: Service, visit: Visit
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Restore Client")
        let barn = Barn(name: "Restore Barn")
        context.insert(client)
        context.insert(barn)
        let horses = ["Milo", "Scout"].map { Horse(name: $0, client: client, currentBarn: barn) }
        horses.forEach(context.insert)
        client.horses = horses
        barn.horses = horses
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: horses, in: context)
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: completed ? Date(timeIntervalSinceReferenceDate: 200) : nil,
            appointment: appointment, in: context
        )
        let service = ModelFixtures.makeService(name: "Trim", in: context)
        for membership in visit.visitHorses {
            membership.outcomeRawValue = VisitOutcome.serviced.rawValue
            _ = ModelFixtures.makeWorkItem(service: service, visitHorse: membership, in: context)
        }
        try DomainGraphValidator.save(context)
        return (container, context, client, service, visit)
    }
}
