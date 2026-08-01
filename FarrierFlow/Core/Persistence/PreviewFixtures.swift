import Foundation
import SwiftData

enum PreviewFixtures {
    enum VisitPreviewState: Equatable {
        case pending
        case partiallySaved
        case completed
        case missingBarn
    }

    struct VisitPreviewFixture {
        let container: ModelContainer
        let visitID: PersistentIdentifier
        let horseID: PersistentIdentifier
    }

    struct HorseHistoryPreviewFixture {
        let container: ModelContainer
        let horseID: PersistentIdentifier
    }

    static func seed(_ context: ModelContext) throws {
        let client = Client(name: "Preview Client")
        let barn = Barn(
            name: "Preview Service Location",
            address: "100 Sample Road"
        )
        context.insert(client)
        context.insert(barn)

        let horse = Horse(
            name: "Preview Horse",
            client: client,
            currentBarn: barn
        )
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)

        let appointment = Appointment(
            startDate: .now,
            barn: barn
        )
        context.insert(appointment)
        barn.appointments.append(appointment)

        let appointmentHorse = AppointmentHorse(
            appointment: appointment,
            horse: horse
        )
        context.insert(appointmentHorse)
        appointment.appointmentHorses.append(appointmentHorse)
        horse.appointmentHorses.append(appointmentHorse)
        try DomainGraphValidator.save(context)
    }

    static func visitPreview(
        state: VisitPreviewState
    ) throws -> VisitPreviewFixture {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Preview Client")
        let barn = Barn(
            name: "Preview Service Location",
            address: "100 Sample Road"
        )
        let firstHorse = Horse(name: "Milo", client: client, currentBarn: barn)
        let secondHorse = Horse(name: "Scout", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        client.horses.append(contentsOf: [firstHorse, secondHorse])
        barn.horses.append(contentsOf: [firstHorse, secondHorse])

        let appointment = Appointment(startDate: .now, barn: barn)
        context.insert(appointment)
        barn.appointments.append(appointment)
        for horse in [firstHorse, secondHorse] {
            let appointmentHorse = AppointmentHorse(appointment: appointment, horse: horse)
            context.insert(appointmentHorse)
            appointment.appointmentHorses.append(appointmentHorse)
            horse.appointmentHorses.append(appointmentHorse)
        }

        let visit = Visit(
            startedAt: .now,
            completedAt: state == .completed || state == .missingBarn ? .now : nil,
            serviceLocationNameSnapshot: barn.name,
            serviceLocationAddressSnapshot: barn.address,
            appointment: appointment,
            barn: barn
        )
        context.insert(visit)
        appointment.visit = visit
        barn.visits.append(visit)
        for horse in [firstHorse, secondHorse] {
            let visitHorse = VisitHorse(visit: visit, horse: horse)
            switch state {
            case .pending:
                break
            case .partiallySaved:
                if horse === firstHorse {
                    visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
                    visitHorse.workNotes = "Front shoes"
                }
            case .completed, .missingBarn:
                if horse === firstHorse {
                    visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
                    visitHorse.workNotes = "Front shoes"
                } else {
                    visitHorse.outcomeRawValue = VisitOutcome.notServiced.rawValue
                }
            }
            context.insert(visitHorse)
            visit.visitHorses.append(visitHorse)
            horse.visitHorses.append(visitHorse)
        }
        try DomainGraphValidator.save(context)

        if state == .missingBarn {
            visit.barn = nil
            try context.save()
        }

        return VisitPreviewFixture(
            container: container,
            visitID: visit.persistentModelID,
            horseID: firstHorse.persistentModelID
        )
    }

    static func horseHistoryPreview(
        populated: Bool
    ) throws -> HorseHistoryPreviewFixture {
        if populated {
            let visitFixture = try visitPreview(state: .completed)
            return HorseHistoryPreviewFixture(
                container: visitFixture.container,
                horseID: visitFixture.horseID
            )
        }

        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Preview Client")
        let barn = Barn(name: "Preview Service Location")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        return HorseHistoryPreviewFixture(
            container: container,
            horseID: horse.persistentModelID
        )
    }
}

#if DEBUG
@MainActor
enum UITestFixtures {
    private static let invoiceClientName = "Invoice Client"

    static func seed(_ scenario: UITestScenario, in container: ModelContainer) throws {
        switch scenario {
        case .invoiceReady:
            try seedInvoiceReady(in: container)
        }
    }

    private static func seedInvoiceReady(in container: ModelContainer) throws {
        let context = container.mainContext
        let existingClients = try context.fetch(FetchDescriptor<Client>())
        guard !existingClients.contains(where: { $0.name == invoiceClientName }) else {
            return
        }

        let invoiceClient = Client(
            name: invoiceClientName,
            phone: "555-0100",
            email: "client@example.com"
        )
        let mixedClient = Client(name: "Mixed Client")
        let barn = Barn(
            name: "Invoice Service Location",
            address: "100 Main Street"
        )
        let service = Service(
            name: "Trim",
            defaultAmountMinorUnits: 5_000
        )
        let invoiceHorse = Horse(
            name: "Milo",
            client: invoiceClient,
            currentBarn: barn,
            defaultService: service
        )
        let mixedHorse = Horse(
            name: "Scout",
            client: mixedClient,
            currentBarn: barn,
            defaultService: service
        )

        [invoiceClient, mixedClient].forEach(context.insert)
        context.insert(barn)
        context.insert(service)
        [invoiceHorse, mixedHorse].forEach(context.insert)
        invoiceClient.horses.append(invoiceHorse)
        mixedClient.horses.append(mixedHorse)
        barn.horses.append(contentsOf: [invoiceHorse, mixedHorse])
        service.horsesUsingAsDefault.append(contentsOf: [invoiceHorse, mixedHorse])

        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: .now)
        let firstStart = calendar.date(byAdding: .hour, value: 9, to: day) ?? day
        let secondStart = calendar.date(byAdding: .hour, value: 10, to: day) ?? day
        let firstAppointment = makeAppointment(
            startDate: firstStart,
            barn: barn,
            horses: [invoiceHorse],
            in: context
        )
        let mixedAppointment = makeAppointment(
            startDate: secondStart,
            barn: barn,
            horses: [invoiceHorse, mixedHorse],
            in: context
        )
        try DomainGraphValidator.save(context)

        try completeVisit(
            for: firstAppointment.persistentModelID,
            startedAt: firstStart,
            in: container
        )
        try completeVisit(
            for: mixedAppointment.persistentModelID,
            startedAt: secondStart,
            in: container
        )
    }

    private static func makeAppointment(
        startDate: Date,
        barn: Barn,
        horses: [Horse],
        in context: ModelContext
    ) -> Appointment {
        let appointment = Appointment(startDate: startDate, barn: barn)
        context.insert(appointment)
        barn.appointments.append(appointment)
        for horse in horses {
            let membership = AppointmentHorse(appointment: appointment, horse: horse)
            context.insert(membership)
            appointment.appointmentHorses.append(membership)
            horse.appointmentHorses.append(membership)
        }
        return appointment
    }

    private static func completeVisit(
        for appointmentID: PersistentIdentifier,
        startedAt: Date,
        in container: ModelContainer
    ) throws {
        let visitID = try VisitStartUseCase.start(
            appointmentID: appointmentID,
            now: startedAt,
            in: container
        )
        let context = ModelContext(container)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visitID, in: context)
        for index in draft.horses.indices {
            draft.horses[index].outcome = .serviced
        }
        let completedAt = startedAt.addingTimeInterval(30 * 60)
        _ = try VisitSaveUseCase.complete(
            draft: draft,
            completedAt: completedAt,
            in: context
        )
    }
}
#endif
