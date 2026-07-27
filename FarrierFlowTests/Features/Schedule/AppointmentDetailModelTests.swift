import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Appointment detail model")
@MainActor
struct AppointmentDetailModelTests {
    @Test
    func deleteResolvesTheDisplayedAppointmentInTheDeletionContext() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let setupContext = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        setupContext.insert(client)
        setupContext.insert(barn)

        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        setupContext.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)

        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: setupContext
        )
        try DomainGraphValidator.save(setupContext)

        let displayContext = ModelContext(container)
        let deletionContext = ModelContext(container)
        let model = AppointmentDetailModel()
        model.load(id: appointment.persistentModelID, in: displayContext)
        let expectedDeletionAppointment = try #require(
            deletionContext.model(for: appointment.persistentModelID) as? Appointment
        )

        let deleted = model.delete(in: deletionContext) { resolvedAppointment, context in
            #expect(context === deletionContext)
            #expect(resolvedAppointment === expectedDeletionAppointment)
            try RecordDeletionRules.delete(resolvedAppointment, in: context)
        }

        #expect(deleted)
        let verificationContext = ModelContext(container)
        #expect(try verificationContext.fetchCount(FetchDescriptor<Appointment>()) == 0)
    }

    @Test
    func visitBlockedDeletionKeepsDetailLoadedAndShowsTheTypedAlert() throws {
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
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        _ = ModelFixtures.makeVisit(appointment: appointment, in: context)
        try DomainGraphValidator.save(context)

        let model = AppointmentDetailModel()
        model.load(id: appointment.persistentModelID, in: context)

        #expect(!model.delete(in: context))
        #expect(model.appointment?.persistentModelID == appointment.persistentModelID)
        let alert = try #require(model.alert)
        let expectedAlert = RecordDeletionBlock.appointmentHasVisit.alert
        #expect(alert.title == expectedAlert.title)
        #expect(alert.message == expectedAlert.message)
        #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 1)
    }

    @Test
    func freshDeletionContextFindsVisitCreatedAfterTheDisplayContextLoaded() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let setupContext = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        setupContext.insert(client)
        setupContext.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        setupContext.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: setupContext
        )
        try DomainGraphValidator.save(setupContext)

        let displayContext = ModelContext(container)
        let model = AppointmentDetailModel()
        model.load(id: appointment.persistentModelID, in: displayContext)

        _ = try VisitStartUseCase.start(
            appointmentID: appointment.persistentModelID,
            now: Date(timeIntervalSinceReferenceDate: 100),
            in: container
        )

        let deletionContext = ModelContext(container)
        #expect(!model.delete(in: deletionContext))
        let alert = try #require(model.alert)
        let expectedAlert = RecordDeletionBlock.appointmentHasVisit.alert
        #expect(alert.title == expectedAlert.title)
        #expect(alert.message == expectedAlert.message)

        let verificationContext = ModelContext(container)
        #expect(try verificationContext.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try verificationContext.fetchCount(FetchDescriptor<Visit>()) == 1)
        try DomainGraphValidator.validateAll(in: verificationContext)
    }
}
