import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("SwiftData relationship insertion", .serialized)
@MainActor
struct SwiftDataRelationshipInsertionTests {
    @Test
    func explicitlyConnectingBothSidesPersistsRequiredRelationships() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        context.insert(client)
        context.insert(barn)

        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)

        let appointment = Appointment(startDate: .now, barn: barn)
        context.insert(appointment)
        barn.appointments.append(appointment)

        let appointmentHorse = AppointmentHorse(
            appointment: appointment,
            horse: horse
        )
        context.insert(appointmentHorse)
        appointment.appointmentHorses.append(appointmentHorse)
        horse.appointmentHorses.append(appointmentHorse)

        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Horse>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
        #expect(horse.client === client)
        #expect(horse.currentBarn === barn)
        #expect(appointment.barn === barn)
        #expect(appointmentHorse.appointment === appointment)
        #expect(appointmentHorse.horse === horse)
    }

    @Test
    func explicitlyConnectingBothSidesPersistsVisitRelationships() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        context.insert(client)
        context.insert(barn)
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        let visit = ModelFixtures.makeVisit(appointment: appointment, in: context)

        try context.save()

        let visitHorse = try #require(visit.visitHorses.first)
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<VisitHorse>()) == 1)
        #expect(appointment.visit === visit)
        #expect(visit.appointment === appointment)
        #expect(visit.barn === barn)
        #expect(barn.visits.contains { $0 === visit })
        #expect(visitHorse.visit === visit)
        #expect(visitHorse.horse === horse)
        #expect(horse.visitHorses.contains { $0 === visitHorse })
    }

    @Test
    func invoiceSnapshotsPersistWithSourceAndOwnershipInverses() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        context.insert(client)
        context.insert(barn)
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
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
        let lineItem = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: workItem,
            in: context
        )

        try DomainGraphValidator.save(context)

        #expect(invoice.client === client)
        #expect(client.invoices.contains { $0 === invoice })
        #expect(invoice.invoiceVisits.contains { $0 === invoiceVisit })
        #expect(invoiceVisit.invoice === invoice)
        #expect(invoiceVisit.sourceVisit === visit)
        #expect(visit.invoiceVisits.contains { $0 === invoiceVisit })
        #expect(invoiceVisit.lineItems.contains { $0 === lineItem })
        #expect(lineItem.invoiceVisit === invoiceVisit)
        #expect(lineItem.sourceWorkItem === workItem)
        #expect(workItem.invoiceLineItem === lineItem)
    }

    @Test
    func deletingInvoiceSnapshotsReleasesOnlyTheSourceWorkItemLink() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        context.insert(client)
        context.insert(barn)
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
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

        context.delete(invoice)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<InvoiceVisit>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<InvoiceLineItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WorkItem>()) == 1)
        #expect(workItem.invoiceLineItem == nil)
    }
}
