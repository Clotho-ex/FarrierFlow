import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice history V4 migration", .serialized)
@MainActor
struct InvoiceHistoryMigrationTests {
    @Test
    func v3ReopenPreservesPaidGBPGraphAndExactJournalBytes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FarrierFlow-History-Migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "business.store")
        let account = UUID(), workspace = UUID(), device = UUID()
        var journal = SyncJournal(accountID: account, workspaceID: workspace, deviceID: device)
        journal.invoicingDeviceID = device
        journal.invoicingGeneration = 3
        let bytes = try JSONEncoder().encode(journal)
        let invoiceID = UUID(), workID = UUID(), photoID = UUID(), paymentID = UUID()
        try autoreleasepool {
            let schema = Schema(versionedSchema: FarrierFlowSchemaV3.self)
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            typealias V = FarrierFlowSchemaV3
            let profile = V.BusinessProfile(name: "Legacy Farrier", nextInvoiceNumber: 17, currencyCode: "GBP")
            let client = V.Client(name: "Pat"), barn = V.Barn(name: "Stable")
            let service = V.Service(name: "Full Set", defaultAmountMinorUnits: 12_500, currencyCode: "GBP")
            let horse = V.Horse(name: "Milo", client: client, currentBarn: barn, defaultService: service)
            let date = Date(timeIntervalSinceReferenceDate: 100)
            let appointment = V.Appointment(startDate: date, barn: barn)
            let booked = V.AppointmentHorse(appointment: appointment, horse: horse)
            let visit = V.Visit(startedAt: date, completedAt: date.addingTimeInterval(10),
                serviceLocationNameSnapshot: "Stable", appointment: appointment, barn: barn)
            let member = V.VisitHorse(outcomeRawValue: VisitOutcome.serviced.rawValue, visit: visit, horse: horse)
            let work = V.WorkItem(syncID: workID, serviceNameSnapshot: "Full Set", amountMinorUnits: 12_500,
                currencyCode: "GBP", service: service, visitHorse: member)
            let photo = V.Photograph(id: photoID, createdAt: date, pixelWidth: 1200,
                pixelHeight: 900, byteCount: 42, visitHorse: member)
            let invoice = V.Invoice(syncID: invoiceID, number: 16, invoiceDate: date,
                clientNameSnapshot: "Original Pat", businessNameSnapshot: "Original Farrier",
                currencyCode: "GBP", client: client)
            let group = V.InvoiceVisit(visitDateSnapshot: date, serviceLocationNameSnapshot: "Stable",
                invoice: invoice, sourceVisit: visit)
            let line = V.InvoiceLineItem(horseNameSnapshot: "Original Milo", serviceNameSnapshot: "Full Set",
                amountMinorUnits: 12_500, currencyCode: "GBP", invoiceVisit: group, sourceWorkItem: work)
            let payment = V.Payment(id: paymentID, amountMinorUnits: 12_500, currencyCode: "GBP",
                receivedAt: date.addingTimeInterval(20), method: .cheque, reference: "CHEQUE-16", invoice: invoice)
            let state = V.SyncState(deviceID: device)
            state.journalData = bytes
            context.insert(profile); context.insert(client); context.insert(barn); context.insert(service)
            context.insert(horse); context.insert(appointment); context.insert(booked); context.insert(visit)
            context.insert(member); context.insert(work); context.insert(photo); context.insert(invoice)
            context.insert(group); context.insert(line); context.insert(payment); context.insert(state)
            client.horses = [horse]; client.invoices = [invoice]
            barn.horses = [horse]; barn.appointments = [appointment]; barn.visits = [visit]
            service.horsesUsingAsDefault = [horse]; service.workItems = [work]
            horse.appointmentHorses = [booked]; horse.visitHorses = [member]
            appointment.appointmentHorses = [booked]; appointment.visit = visit
            visit.visitHorses = [member]; visit.invoiceVisits = [group]
            member.workItems = [work]; member.photographs = [photo]
            invoice.invoiceVisits = [group]; group.lineItems = [line]; work.invoiceLineItem = line
            try invoice.recordCompletedPayment(payment)
            try context.save()
        }
        for _ in 0..<2 {
            try autoreleasepool {
                let container = try ModelContainerFactory.persistentStoreTest(at: url)
                let context = ModelContext(container)
                try DomainGraphValidator.validateAll(in: context)
                let work = try #require(context.fetch(FetchDescriptor<WorkItem>()).first)
                let invoice = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
                #expect(work.syncID == workID && work.billingHoldID == nil)
                #expect(invoice.syncID == invoiceID && invoice.number == 16)
                #expect(invoice.currencyCode == "GBP" && invoice.clientNameSnapshot == "Original Pat")
                #expect(invoice.statusRawValue == "paid" && invoice.payments.first?.id == paymentID)
                #expect(invoice.payments.first?.amountMinorUnits == 12_500)
                #expect(invoice.payments.first?.reference == "CHEQUE-16")
                #expect(try context.fetch(FetchDescriptor<Photograph>()).first?.id == photoID)
                #expect(try SyncJournalStore(container: container).journal() == journal)
                let syncEntity = try #require(container.schema.entitiesByName["SyncState"])
                #expect(syncEntity.attributes.contains { $0.name == "journalData" })
                #expect(try context.fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()).first?.journalData == bytes)
            }
        }
    }
}
