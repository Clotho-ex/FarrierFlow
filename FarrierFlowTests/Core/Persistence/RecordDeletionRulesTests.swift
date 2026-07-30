import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Record deletion rules", .serialized)
@MainActor
struct RecordDeletionRulesTests {
    @Test
    func referencedClientBarnAndHorseAreBlocked() throws {
        let graph = try makeGraph()

        #expect(throws: RecordDeletionBlock.clientHasHorses) {
            try RecordDeletionRules.delete(graph.client, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.barnHasHorsesAndAppointments) {
            try RecordDeletionRules.delete(graph.barn, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.horseHasAppointments) {
            try RecordDeletionRules.delete(graph.horse, in: graph.context)
        }
        #expect(try graph.context.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
    }

    @Test
    func deletingAppointmentCascadesOnlyItsJoin() throws {
        let graph = try makeGraph()
        try RecordDeletionRules.delete(graph.appointment, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
    }

    @Test
    func deletingAppointmentHorseRemovesOnlyThatMembership() throws {
        let graph = try makeGraph()
        let secondClient = Client(name: "Jordan")
        graph.context.insert(secondClient)
        let secondHorse = Horse(
            name: "Scout",
            client: secondClient,
            currentBarn: graph.barn
        )
        graph.context.insert(secondHorse)
        secondClient.horses.append(secondHorse)
        graph.barn.horses.append(secondHorse)
        let appointmentHorse = AppointmentHorse(
            appointment: graph.appointment,
            horse: secondHorse
        )
        graph.context.insert(appointmentHorse)
        graph.appointment.appointmentHorses.append(appointmentHorse)
        secondHorse.appointmentHorses.append(appointmentHorse)
        try graph.context.save()

        try RecordDeletionRules.delete(appointmentHorse, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Client>()) == 2)
        #expect(try graph.context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 2)
        #expect(graph.appointment.appointmentHorses.first?.horse === graph.horse)
    }

    @Test
    func visitReferencesBlockAppointmentBarnAndHorseDeletion() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        try graph.context.save()

        #expect(throws: RecordDeletionBlock.appointmentHasVisit) {
            try RecordDeletionRules.delete(graph.appointment, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.barnHasVisits) {
            try RecordDeletionRules.delete(graph.barn, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.horseHasVisits) {
            try RecordDeletionRules.delete(graph.horse, in: graph.context)
        }
        #expect(visit.completedAt == nil)
    }

    @Test
    func blockedAppointmentDeletionPreservesItsVisitAndMemberships() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        try graph.context.save()

        #expect(throws: RecordDeletionBlock.appointmentHasVisit) {
            try RecordDeletionRules.delete(graph.appointment, in: graph.context)
        }
        #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<VisitHorse>()) == 1)
        #expect(graph.appointment.visit === visit)
    }

    @Test
    func discardingInProgressVisitCascadesOnlyItsVisitHorses() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        try graph.context.save()

        try RecordDeletionRules.delete(visit, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<VisitHorse>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(graph.appointment.visit == nil)
    }

    @Test
    func deletingVisitHorseNeverDeletesVisitOrHorse() throws {
        let graph = try makeGraph()
        let secondClient = Client(name: "Jordan")
        let secondHorse = Horse(
            name: "Scout",
            client: secondClient,
            currentBarn: graph.barn
        )
        graph.context.insert(secondClient)
        graph.context.insert(secondHorse)
        secondClient.horses.append(secondHorse)
        graph.barn.horses.append(secondHorse)
        let appointmentHorse = AppointmentHorse(
            appointment: graph.appointment,
            horse: secondHorse
        )
        graph.context.insert(appointmentHorse)
        graph.appointment.appointmentHorses.append(appointmentHorse)
        secondHorse.appointmentHorses.append(appointmentHorse)
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        try graph.context.save()
        let visitHorse = try #require(visit.visitHorses.first)

        graph.context.delete(visitHorse)
        try graph.context.save()

        #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 2)
    }

    @Test
    func completedVisitCannotBeDeleted() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            completedAt: .now,
            appointment: graph.appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        try graph.context.save()

        #expect(throws: RecordDeletionBlock.completedVisitCannotBeDeleted) {
            try RecordDeletionRules.delete(visit, in: graph.context)
        }
    }

    @Test
    func emptyRecordsCanBeDeleted() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Empty Client")
        let barn = Barn(name: "Empty Barn")
        context.insert(client)
        context.insert(barn)
        try context.save()
        try RecordDeletionRules.delete(client, in: context)
        try RecordDeletionRules.delete(barn, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Barn>()) == 0)
    }

    @Test
    func archiveRejectsServiceUsedAsHorseDefault() throws {
        let graph = try makeGraph()
        let service = ModelFixtures.makeService(in: graph.context)
        graph.horse.defaultService = service
        service.horsesUsingAsDefault.append(graph.horse)

        #expect(throws: RecordDeletionBlock.serviceHasHorseDefaults) {
            try RecordDeletionRules.archive(service, in: graph.context)
        }
        #expect(!service.isArchived)
    }

    @Test
    func archiveAllowsServiceAfterDefaultsAreClearedAndPreservesRecordedWork() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let visitHorse = try #require(visit.visitHorses.first)
        let service = ModelFixtures.makeService(in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: graph.context
        )

        try RecordDeletionRules.archive(service, in: graph.context)

        #expect(service.isArchived)
        #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 1)
    }

    @Test
    func deletingServiceRejectsDefaultAndWorkItemReferences() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let visitHorse = try #require(visit.visitHorses.first)
        let service = ModelFixtures.makeService(in: graph.context)
        graph.horse.defaultService = service
        service.horsesUsingAsDefault.append(graph.horse)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: graph.context
        )

        #expect(throws: RecordDeletionBlock.serviceHasHorseDefaultsAndWorkItems) {
            try RecordDeletionRules.delete(service, in: graph.context)
        }
        #expect(try graph.context.fetchCount(FetchDescriptor<Service>()) == 1)
    }

    @Test
    func deletingWorkItemPreservesServiceAndVisitHorse() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let visitHorse = try #require(visit.visitHorses.first)
        let service = ModelFixtures.makeService(in: graph.context)
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: graph.context
        )

        try RecordDeletionRules.delete(workItem, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<Service>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<VisitHorse>()) == 1)
    }

    @Test
    func businessProfileCannotBeDeleted() throws {
        let graph = try makeGraph()
        let profile = ModelFixtures.makeBusinessProfile(in: graph.context)
        try DomainGraphValidator.save(graph.context)

        #expect(throws: RecordDeletionBlock.businessProfileCannotBeDeleted) {
            try RecordDeletionRules.delete(profile, in: graph.context)
        }
        #expect(try graph.context.fetchCount(FetchDescriptor<BusinessProfile>()) == 1)
    }

    @Test
    func invoiceReferencesBlockClientVisitAndWorkItemDeletion() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(in: graph.context)
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: graph.context
        )
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 2, in: graph.context)
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: graph.client,
            businessProfile: profile,
            in: graph.context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: graph.context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: workItem,
            in: graph.context
        )
        try DomainGraphValidator.save(graph.context)

        #expect(throws: RecordDeletionBlock.clientHasInvoices) {
            try RecordDeletionRules.delete(graph.client, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.visitHasInvoiceLineItems) {
            try RecordDeletionRules.delete(visit, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.workItemHasInvoiceLineItem) {
            try RecordDeletionRules.delete(workItem, in: graph.context)
        }
        #expect(try graph.context.fetchCount(FetchDescriptor<Invoice>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 1)
    }

    @Test
    func deletingUnreferencedServiceRemovesOnlyTheService() throws {
        let graph = try makeGraph()
        let service = ModelFixtures.makeService(in: graph.context)

        try RecordDeletionRules.delete(service, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<Service>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
    }

    private func makeGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        client: Client,
        barn: Barn,
        horse: Horse,
        appointment: Appointment
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        try context.save()
        return (container, context, client, barn, horse, appointment)
    }
}
