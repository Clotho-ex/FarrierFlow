import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Appointment service migration", .serialized)
@MainActor
struct AppointmentServiceMigrationTests {
    @Test
    func v4StoreMigratesThenKeepsAppointmentServiceAfterReopening() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "appointments.store")
        let memberID = UUID()
        try autoreleasepool {
            typealias V = FarrierFlowSchemaV4
            let schema = Schema(versionedSchema: V.self)
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            let client = V.Client(name: "Pat")
            let barn = V.Barn(name: "Stable")
            let horse = V.Horse(name: "Milo", client: client, currentBarn: barn)
            let service = V.Service(name: "Trim", defaultAmountMinorUnits: 5_000)
            let appointment = V.Appointment(startDate: .now, barn: barn)
            let member = V.AppointmentHorse(syncID: memberID, appointment: appointment, horse: horse)
            context.insert(client)
            context.insert(barn)
            context.insert(horse)
            context.insert(service)
            context.insert(appointment)
            context.insert(member)
            client.horses = [horse]
            barn.horses = [horse]
            barn.appointments = [appointment]
            horse.appointmentHorses = [member]
            appointment.appointmentHorses = [member]
            try context.save()
        }
        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            let context = container.mainContext
            try DomainGraphValidator.validateAll(in: context)
            let member = try #require(context.fetch(FetchDescriptor<AppointmentHorse>()).first)
            #expect(member.syncID == memberID)
            #expect(member.plannedService == nil)
            let appointment = try #require(member.appointment)
            let horse = try #require(member.horse)
            let service = try #require(context.fetch(FetchDescriptor<Service>()).first)
            let editor = AppointmentEditorModel(appointment: appointment)
            editor.load(in: context)
            editor.draft.serviceIDsByHorse[horse.persistentModelID] = service.persistentModelID
            #expect(editor.save(in: context) != nil)
        }
        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            let context = container.mainContext
            try DomainGraphValidator.validateAll(in: context)
            let member = try #require(context.fetch(FetchDescriptor<AppointmentHorse>()).first)
            #expect(member.syncID == memberID)
            #expect(member.plannedService?.name == "Trim")
            #expect(member.horse?.defaultService == nil)
            let appointment = try #require(member.appointment)
            let editor = AppointmentEditorModel(appointment: appointment)
            editor.load(in: context)
            let horse = try #require(member.horse)
            #expect(editor.draft.serviceIDsByHorse[horse.persistentModelID] == member.plannedService?.persistentModelID)
        }
    }
}
