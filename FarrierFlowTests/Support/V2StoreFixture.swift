import Foundation
import SwiftData
@testable import FarrierFlow

enum V2StoreFixture {
    static func writeCompleteVisitGraph(to url: URL) throws {
        let schema = Schema(versionedSchema: FarrierFlowSchemaV2.self)
        let configuration = ModelConfiguration(
            "FarrierFlowV2MigrationFixture",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let client = FarrierFlowSchemaV2.Client(name: "Alex Carter")
        let barn = FarrierFlowSchemaV2.Barn(
            name: "North Field",
            address: "1 Field Road"
        )
        let horse = FarrierFlowSchemaV2.Horse(
            name: "Milo",
            client: client,
            currentBarn: barn
        )
        let appointment = FarrierFlowSchemaV2.Appointment(
            startDate: Date(timeIntervalSince1970: 1_722_000_000),
            barn: barn
        )
        let appointmentHorse = FarrierFlowSchemaV2.AppointmentHorse(
            appointment: appointment,
            horse: horse
        )
        let visit = FarrierFlowSchemaV2.Visit(
            startedAt: Date(timeIntervalSince1970: 1_722_000_100),
            completedAt: Date(timeIntervalSince1970: 1_722_000_500),
            serviceLocationNameSnapshot: barn.name,
            serviceLocationAddressSnapshot: barn.address,
            appointment: appointment,
            barn: barn
        )
        let visitHorse = FarrierFlowSchemaV2.VisitHorse(
            outcomeRawValue: "serviced",
            workNotes: "Front shoes",
            visit: visit,
            horse: horse
        )

        for model in [
            client as any PersistentModel,
            barn,
            horse,
            appointment,
            appointmentHorse,
            visit,
            visitHorse,
        ] {
            context.insert(model)
        }

        client.horses.append(horse)
        barn.horses.append(horse)
        barn.appointments.append(appointment)
        barn.visits.append(visit)
        horse.appointmentHorses.append(appointmentHorse)
        horse.visitHorses.append(visitHorse)
        appointment.appointmentHorses.append(appointmentHorse)
        appointment.visit = visit
        visit.visitHorses.append(visitHorse)

        try context.save()
    }
}
