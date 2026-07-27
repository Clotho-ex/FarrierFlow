import Foundation
import SwiftData
@testable import FarrierFlow

enum V1StoreFixture {
    static func writeCompleteGraph(to url: URL) throws {
        let schema = Schema(versionedSchema: FarrierFlowSchemaV1.self)
        let configuration = ModelConfiguration(
            "FarrierFlowV1MigrationFixture",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let alex = FarrierFlowSchemaV1.Client(
            name: "Alex Carter",
            phone: "555-0100",
            email: "alex@example.com",
            notes: "Prefers text messages"
        )
        let jordan = FarrierFlowSchemaV1.Client(
            name: "Jordan Lee",
            phone: "555-0101",
            email: "jordan@example.com",
            notes: "Gate code on file"
        )
        let barn = FarrierFlowSchemaV1.Barn(
            name: "North Field",
            address: "1 Field Road",
            contactNotes: "Use the side entrance"
        )
        let milo = FarrierFlowSchemaV1.Horse(
            name: "Milo",
            safetyNotes: "Needs a quiet approach",
            appointmentIntervalWeeks: 6,
            client: alex,
            currentBarn: barn
        )
        let scout = FarrierFlowSchemaV1.Horse(
            name: "Scout",
            safetyNotes: nil,
            appointmentIntervalWeeks: 8,
            client: jordan,
            currentBarn: barn
        )
        let appointment = FarrierFlowSchemaV1.Appointment(
            startDate: Date(timeIntervalSince1970: 1_722_000_000),
            notes: "Check front left hoof",
            expectedDurationMinutes: 75,
            barn: barn
        )
        let miloMembership = FarrierFlowSchemaV1.AppointmentHorse(
            appointment: appointment,
            horse: milo
        )
        let scoutMembership = FarrierFlowSchemaV1.AppointmentHorse(
            appointment: appointment,
            horse: scout
        )

        context.insert(alex)
        context.insert(jordan)
        context.insert(barn)
        context.insert(milo)
        context.insert(scout)
        context.insert(appointment)
        context.insert(miloMembership)
        context.insert(scoutMembership)
        alex.horses.append(milo)
        jordan.horses.append(scout)
        barn.horses.append(contentsOf: [milo, scout])
        barn.appointments.append(appointment)
        appointment.appointmentHorses.append(contentsOf: [miloMembership, scoutMembership])
        milo.appointmentHorses.append(miloMembership)
        scout.appointmentHorses.append(scoutMembership)

        try context.save()
    }
}
