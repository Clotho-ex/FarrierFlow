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
