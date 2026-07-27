import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("V1 to V2 schema migration")
@MainActor
struct SchemaMigrationTests {
    @Test
    func existingV1GraphMigratesWithoutFabricatingVisitData() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-V1-to-V2-Migration-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")

        try autoreleasepool {
            try V1StoreFixture.writeCompleteGraph(to: storeURL)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let clients = try context.fetch(FetchDescriptor<Client>())
            let barns = try context.fetch(FetchDescriptor<Barn>())
            let horses = try context.fetch(FetchDescriptor<Horse>())
            let appointments = try context.fetch(FetchDescriptor<Appointment>())
            let appointmentHorses = try context.fetch(FetchDescriptor<AppointmentHorse>())

            let alex = try #require(clients.first { $0.name == "Alex Carter" })
            let jordan = try #require(clients.first { $0.name == "Jordan Lee" })
            let barn = try #require(barns.first { $0.name == "North Field" })
            let milo = try #require(horses.first { $0.name == "Milo" })
            let scout = try #require(horses.first { $0.name == "Scout" })
            let appointment = try #require(appointments.first)

            #expect(clients.count == 2)
            #expect(barns.count == 1)
            #expect(horses.count == 2)
            #expect(appointments.count == 1)
            #expect(appointmentHorses.count == 2)
            #expect(alex.phone == "555-0100")
            #expect(alex.email == "alex@example.com")
            #expect(alex.notes == "Prefers text messages")
            #expect(jordan.phone == "555-0101")
            #expect(jordan.email == "jordan@example.com")
            #expect(jordan.notes == "Gate code on file")
            #expect(barn.address == "1 Field Road")
            #expect(barn.contactNotes == "Use the side entrance")
            #expect(milo.safetyNotes == "Needs a quiet approach")
            #expect(milo.appointmentIntervalWeeks == 6)
            #expect(scout.safetyNotes == nil)
            #expect(scout.appointmentIntervalWeeks == 8)
            #expect(appointment.startDate == Date(timeIntervalSince1970: 1_722_000_000))
            #expect(appointment.notes == "Check front left hoof")
            #expect(appointment.expectedDurationMinutes == 75)

            #expect(milo.client === alex)
            #expect(scout.client === jordan)
            #expect(milo.currentBarn === barn)
            #expect(scout.currentBarn === barn)
            #expect(appointment.barn === barn)
            #expect(alex.horses.contains { $0 === milo })
            #expect(jordan.horses.contains { $0 === scout })
            #expect(Set(barn.horses.map(\.name)) == ["Milo", "Scout"])
            #expect(barn.appointments.contains { $0 === appointment })
            #expect(milo.appointmentHorses.count == 1)
            #expect(scout.appointmentHorses.count == 1)
            #expect(appointment.appointmentHorses.count == 2)
            #expect(Set(appointment.appointmentHorses.compactMap(\.horse?.name)) == ["Milo", "Scout"])
            #expect(Set(appointment.appointmentHorses.compactMap(\.appointment?.persistentModelID)).count == 1)

            #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<VisitHorse>()) == 0)
            #expect(appointment.visit == nil)
        }
    }
}
