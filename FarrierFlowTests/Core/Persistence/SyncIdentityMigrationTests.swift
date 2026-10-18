import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Sync identity migration", .serialized)
@MainActor
struct SyncIdentityMigrationTests {
    @Test
    func everySyncableEntityStoresARecordIdentity() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        for entity in container.schema.entities {
            if entity.name == "SyncState" { continue }
            let field = ["Photograph", "Payment"].contains(entity.name) ? "id" : "syncID"
            #expect(entity.attributes.contains { $0.name == field },
                    "\(entity.name) must have an identity independent of its name or invoice number")
        }
    }
    @Test
    func v2StoreMigratesEveryIdentityAndPreservesGBPHistory() throws {
        let storeURL = try makeStoreURL(prefix: "FarrierFlow-V2-Sync-Migration-")
        let photographID = UUID()
        let paymentID = UUID()
        let visitDate = Date(timeIntervalSinceReferenceDate: 100)
        let paidAt = Date(timeIntervalSinceReferenceDate: 300)

        try autoreleasepool {
            let schema = Schema(versionedSchema: FarrierFlowSchemaV2.self)
            let configuration = ModelConfiguration(
                "FarrierFlowV2MigrationSource",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let profile = FarrierFlowSchemaV2.BusinessProfile(
                name: "Legacy Farrier",
                nextInvoiceNumber: 17,
                currencyCode: "GBP"
            )
            let client = FarrierFlowSchemaV2.Client(name: "Legacy Client")
            let barn = FarrierFlowSchemaV2.Barn(
                name: "Legacy Barn",
                address: "1 Stable Lane"
            )
            let service = FarrierFlowSchemaV2.Service(
                name: "Legacy Full Set",
                defaultAmountMinorUnits: 12_500,
                currencyCode: "GBP"
            )
            let horse = FarrierFlowSchemaV2.Horse(
                name: "Legacy Horse",
                client: client,
                currentBarn: barn,
                defaultService: service
            )
            let appointment = FarrierFlowSchemaV2.Appointment(
                startDate: visitDate,
                barn: barn
            )
            let appointmentHorse = FarrierFlowSchemaV2.AppointmentHorse(
                appointment: appointment,
                horse: horse
            )
            let visit = FarrierFlowSchemaV2.Visit(
                startedAt: visitDate,
                completedAt: Date(timeIntervalSinceReferenceDate: 200),
                serviceLocationNameSnapshot: barn.name,
                serviceLocationAddressSnapshot: barn.address,
                appointment: appointment,
                barn: barn
            )
            let visitHorse = FarrierFlowSchemaV2.VisitHorse(
                outcomeRawValue: VisitOutcome.serviced.rawValue,
                workNotes: "Legacy work",
                visit: visit,
                horse: horse
            )
            let photograph = FarrierFlowSchemaV2.Photograph(
                id: photographID,
                createdAt: visitDate,
                pixelWidth: 1_200,
                pixelHeight: 900,
                byteCount: 42,
                visitHorse: visitHorse
            )
            let workItem = FarrierFlowSchemaV2.WorkItem(
                serviceNameSnapshot: service.name,
                amountMinorUnits: 12_500,
                currencyCode: "GBP",
                service: service,
                visitHorse: visitHorse
            )
            let invoice = FarrierFlowSchemaV2.Invoice(
                number: 16,
                invoiceDate: Date(timeIntervalSinceReferenceDate: 250),
                clientNameSnapshot: client.name,
                businessNameSnapshot: profile.name,
                currencyCode: "GBP",
                client: client
            )
            let invoiceVisit = FarrierFlowSchemaV2.InvoiceVisit(
                visitDateSnapshot: visit.startedAt,
                serviceLocationNameSnapshot: visit.serviceLocationNameSnapshot,
                serviceLocationAddressSnapshot: visit.serviceLocationAddressSnapshot,
                invoice: invoice,
                sourceVisit: visit
            )
            let lineItem = FarrierFlowSchemaV2.InvoiceLineItem(
                horseNameSnapshot: horse.name,
                serviceNameSnapshot: workItem.serviceNameSnapshot,
                amountMinorUnits: workItem.amountMinorUnits,
                currencyCode: "GBP",
                invoiceVisit: invoiceVisit,
                sourceWorkItem: workItem
            )
            let payment = FarrierFlowSchemaV2.Payment(
                id: paymentID,
                amountMinorUnits: 12_500,
                currencyCode: "GBP",
                receivedAt: paidAt,
                method: .cheque,
                reference: "LEGACY-16",
                invoice: invoice
            )
            context.insert(profile)
            context.insert(client)
            context.insert(FarrierFlowSchemaV2.Client(name: "Legacy Client"))
            context.insert(barn)
            context.insert(service)
            context.insert(horse)
            context.insert(appointment)
            context.insert(appointmentHorse)
            context.insert(visit)
            context.insert(visitHorse)
            context.insert(photograph)
            context.insert(workItem)
            context.insert(invoice)
            context.insert(invoiceVisit)
            context.insert(lineItem)
            context.insert(payment)
            client.horses.append(horse)
            client.invoices.append(invoice)
            barn.horses.append(horse)
            barn.appointments.append(appointment)
            barn.visits.append(visit)
            service.horsesUsingAsDefault.append(horse)
            service.workItems.append(workItem)
            appointment.appointmentHorses.append(appointmentHorse)
            appointment.visit = visit
            horse.appointmentHorses.append(appointmentHorse)
            horse.visitHorses.append(visitHorse)
            visit.visitHorses.append(visitHorse)
            visit.invoiceVisits.append(invoiceVisit)
            visitHorse.photographs.append(photograph)
            visitHorse.workItems.append(workItem)
            invoice.invoiceVisits.append(invoiceVisit)
            invoiceVisit.lineItems.append(lineItem)
            workItem.invoiceLineItem = lineItem
            try invoice.recordCompletedPayment(payment)
            try context.save()
        }

        let firstIDs = try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let profile = try #require(
                context.fetch(FetchDescriptor<BusinessProfile>()).first
            )
            let service = try #require(
                context.fetch(FetchDescriptor<Service>()).first
            )
            let horse = try #require(context.fetch(FetchDescriptor<Horse>()).first)
            let appointment = try #require(
                context.fetch(FetchDescriptor<Appointment>()).first
            )
            let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)
            let visitHorse = try #require(visit.visitHorses.first)
            let photograph = try #require(visitHorse.photographs.first)
            let workItem = try #require(visitHorse.workItems.first)
            let invoice = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
            let invoiceVisit = try #require(invoice.invoiceVisits.first)
            let lineItem = try #require(invoiceVisit.lineItems.first)
            let payment = try #require(invoice.payments.first)

            #expect(profile.name == "Legacy Farrier")
            #expect(profile.nextInvoiceNumber == 17)
            #expect(profile.currencyCode == "GBP")
            #expect(service.name == "Legacy Full Set")
            #expect(service.defaultAmountMinorUnits == 12_500)
            #expect(service.currencyCode == "GBP")
            #expect(horse.defaultService === service)
            #expect(appointment.visit === visit)
            #expect(visitHorse.horse === horse)
            #expect(photograph.id == photographID)
            #expect(photograph.visitHorse === visitHorse)
            #expect(workItem.service === service)
            #expect(workItem.amountMinorUnits == 12_500)
            #expect(workItem.currencyCode == "GBP")
            #expect(invoice.number == 16)
            #expect(invoice.statusRawValue == InvoiceStatus.paid.rawValue)
            #expect(invoice.currencyCode == "GBP")
            #expect(invoiceVisit.sourceVisit === visit)
            #expect(lineItem.sourceWorkItem === workItem)
            #expect(lineItem.amountMinorUnits == 12_500)
            #expect(lineItem.currencyCode == "GBP")
            #expect(workItem.invoiceLineItem === lineItem)
            #expect(payment.receivedAt == paidAt)
            #expect(payment.id == paymentID)
            #expect(payment.currencyCode == "GBP")
            #expect(payment.method == .cheque)
            #expect(payment.reference == "LEGACY-16")
            #expect(try context.fetchCount(FetchDescriptor<Client>()) == 2)
            #expect(try context.fetchCount(FetchDescriptor<Barn>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<InvoiceLineItem>()) == 1)
            try DomainGraphValidator.validateAll(in: context)
            return try identities(in: context)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            #expect(try identities(in: context) == firstIDs)
            try SyncRecordIdentity.initializeAll(in: context)
            #expect(try identities(in: context) == firstIDs)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            #expect(try identities(in: ModelContext(container)) == firstIDs)
        }
    }


    @Test
    func restoredIdentitySurvivesSavingAndReopening() throws {
        let storeURL = try makeStoreURL(prefix: "FarrierFlow-Restored-Identity-")
        let restoredID = UUID()
        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            context.insert(Client(syncID: restoredID, name: "Restored Client"))
            try context.save()
        }
        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let client = try #require(
                ModelContext(container).fetch(FetchDescriptor<Client>()).first
            )
            #expect(client.syncID == restoredID)
        }
    }

    @Test
    func freshLookalikeRecordsHaveDifferentPermanentIdentities() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let first = Client(name: "John Smith")
        let second = Client(name: "John Smith")
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()
        let ids = try SyncRecordIdentity.requireIDs([first, second])
        #expect(ids.count == 2)
        #expect(ids[0] != ids[1])
        first.initializeSyncIdentity()
        #expect(first.syncID == ids[0])
    }

    @Test
    func repeatedIdentityIsRejectedBeforeUpload() throws {
        let client = Client(name: "John Smith")
        let id = try #require(client.syncID)
        #expect(throws: SyncIdentityError.duplicateIdentity(id)) {
            try SyncRecordIdentity.requireIDs([client, client])
        }
    }

    private func makeStoreURL(prefix: String) throws -> URL {
        try TemporaryStoreFixtures.makeDirectory(prefix: prefix)
            .appending(path: "FarrierFlow.store")
    }

    private func identities(in context: ModelContext) throws -> [String: Set<UUID>] {
        [
            "Client": try ids(Client.self, in: context),
            "Barn": try ids(Barn.self, in: context),
            "Horse": try ids(Horse.self, in: context),
            "Appointment": try ids(Appointment.self, in: context),
            "AppointmentHorse": try ids(AppointmentHorse.self, in: context),
            "Visit": try ids(Visit.self, in: context),
            "VisitHorse": try ids(VisitHorse.self, in: context),
            "Photograph": try ids(Photograph.self, in: context),
            "Service": try ids(Service.self, in: context),
            "WorkItem": try ids(WorkItem.self, in: context),
            "BusinessProfile": try ids(BusinessProfile.self, in: context),
            "Invoice": try ids(Invoice.self, in: context),
            "InvoiceVisit": try ids(InvoiceVisit.self, in: context),
            "InvoiceLineItem": try ids(InvoiceLineItem.self, in: context),
            "Payment": try ids(Payment.self, in: context),
        ]
    }

    private func ids<T: SyncRecordIdentifying>(_ type: T.Type, in context: ModelContext) throws -> Set<UUID> {
        let records = try context.fetch(FetchDescriptor<T>())
        #expect(!records.isEmpty)
        return Set(try SyncRecordIdentity.requireIDs(records))
    }
}
