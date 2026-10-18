import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Sync business graph", .serialized)
@MainActor
struct SyncGraphCodecTests {
    @Test
    func scheduledServiceRoundTripsWithoutChangingHorseDefaultAndLegacyGraphStillLoads() throws {
        let source = try makeGraph()
        let context = source.mainContext
        let member = try #require(context.fetch(FetchDescriptor<AppointmentHorse>()).first)
        let service = try #require(context.fetch(FetchDescriptor<Service>()).first)
        member.plannedService = service
        try DomainGraphValidator.save(context)
        let records = try SyncGraphCodec.capture(in: context)
        let destination = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(records, in: destination.mainContext)
        let restored = try #require(destination.mainContext.fetch(FetchDescriptor<AppointmentHorse>()).first {
            $0.syncID == member.syncID
        })
        #expect(restored.plannedService?.syncID == service.syncID)
        #expect(try SyncGraphCodec.capture(in: destination.mainContext) == records)
        let legacy = records.map { record in
            var fields = record.fields
            if record.kind == .appointmentHorse { fields.removeValue(forKey: "plannedService") }
            return SyncRecord(id: record.id, kind: record.kind, fields: fields)
        }
        let legacyDestination = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(legacy, in: legacyDestination.mainContext)
        #expect(try legacyDestination.mainContext.fetch(FetchDescriptor<AppointmentHorse>())
            .allSatisfy { $0.plannedService == nil })
    }

    @Test
    func completePaidGBPHistoryRoundTripsEveryIdentityAndValue() throws {
        let source = try makeGraph()
        let records = try SyncGraphCodec.capture(in: source.mainContext)
        #expect(Set(records.map(\.kind)) == Set(SyncRecordKind.allCases))
        let destination = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(records, in: destination.mainContext)
        #expect(try SyncGraphCodec.capture(in: destination.mainContext) == records)
        let invoice = try #require(
            destination.mainContext.fetch(FetchDescriptor<Invoice>()).first
        )
        #expect(invoice.number == 16)
        #expect(invoice.currencyCode == "GBP")
        #expect(invoice.statusRawValue == InvoiceStatus.paid.rawValue)
        #expect(invoice.invoiceVisits.first?.lineItems.first?.amountMinorUnits == 12_500)
        #expect(invoice.payments.first?.reference == "CHEQUE-16")
        #expect(invoice.invoiceVisits.first?.sourceVisit?.appointment?.visit ===
                invoice.invoiceVisits.first?.sourceVisit)
    }

    @Test
    func applyingSameGraphTwiceDoesNotDuplicateRecordsOrReplaceLocalObjects() throws {
        let source = try makeGraph()
        let records = try SyncGraphCodec.capture(in: source.mainContext)
        let destination = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(records, in: destination.mainContext)
        let firstClient = try #require(
            destination.mainContext.fetch(FetchDescriptor<Client>()).first
        )
        try SyncGraphCodec.apply(records, in: destination.mainContext)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try destination.mainContext.fetch(FetchDescriptor<Client>()).first === firstClient)
    }

    @Test
    func invalidRemoteRelationshipLeavesCommittedLocalGraphUntouched() throws {
        let source = try makeGraph()
        let before = try SyncGraphCodec.capture(in: source.mainContext)
        let invalid = before.filter { $0.kind != .client }
        #expect(throws: (any Error).self) {
            try SyncGraphCodec.apply(invalid, in: source.mainContext)
        }
        let verification = ModelContext(source)
        #expect(try SyncGraphCodec.capture(in: verification) == before)
    }

    @Test
    func remoteMutationCannotOverwriteIssuedInvoiceSnapshot() throws {
        let source = try makeGraph()
        let before = try SyncGraphCodec.capture(in: source.mainContext)
        let changed = before.map { record in
            guard record.kind == .invoice else { return record }
            var fields = record.fields
            fields["number"] = .integer(99)
            return SyncRecord(id: record.id, kind: record.kind, fields: fields)
        }
        #expect(throws: SyncGraphError.immutableHistoryChanged) {
            try SyncGraphCodec.apply(changed, in: source.mainContext)
        }
        #expect(try SyncGraphCodec.capture(in: ModelContext(source)) == before)
    }

    @Test
    func captureRejectsUnsavedEditorDrafts() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        context.insert(Client(name: "Unsaved"))
        #expect(throws: SyncGraphError.unsavedChanges) {
            try SyncGraphCodec.capture(in: context)
        }
    }

    @Test
    func remoteGraphAndJournalCursorCommitTogether() throws {
        let source = try makeGraph()
        let store = SyncJournalStore(container: source)
        try store.bind(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        let savedJournal = try store.journal()
        var journal = try #require(savedJournal)
        journal.cursor = 9
        let records = try SyncGraphCodec.capture(in: ModelContext(source))
            .map { record in
                guard record.kind == .client else { return record }
                var fields = record.fields
                fields["name"] = .string("Cloud name")
                return SyncRecord(id: record.id, kind: record.kind, fields: fields)
            }
        try SyncGraphCodec.apply(records, in: ModelContext(source), journal: journal)
        #expect(try store.journal()?.cursor == 9)
        #expect(try ModelContext(source).fetch(FetchDescriptor<Client>()).first?.name == "Cloud name")
    }

    @Test
    func failedJournalBindingRollsBackRemoteGraphChanges() throws {
        let source = try makeGraph()
        let store = SyncJournalStore(container: source)
        try store.bind(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        let before = try SyncGraphCodec.capture(in: ModelContext(source))
        let records = before.map { record in
            guard record.kind == .client else { return record }
            var fields = record.fields
            fields["name"] = .string("Wrong account")
            return SyncRecord(id: record.id, kind: record.kind, fields: fields)
        }
        let wrongJournal = SyncJournal(
            accountID: UUID(), workspaceID: UUID(), deviceID: UUID()
        )
        #expect(throws: SyncJournalError.accountMismatch) {
            try SyncGraphCodec.apply(
                records, in: ModelContext(source), journal: wrongJournal
            )
        }
        #expect(try SyncGraphCodec.capture(in: ModelContext(source)) == before)
        #expect(try store.journal()?.cursor == 0)
    }

    private func makeGraph() throws -> ModelContainer {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Pat")
        let barn = Barn(name: "Stable", address: "1 Stable Lane")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let profile = ModelFixtures.makeBusinessProfile(
            nextInvoiceNumber: 17, currencyCode: "GBP", in: context
        )
        let service = ModelFixtures.makeService(currencyCode: "GBP", in: context)
        horse.defaultService = service
        service.horsesUsingAsDefault.append(horse)
        let date = Date(timeIntervalSinceReferenceDate: 123.123456789)
        let appointment = ModelFixtures.makeAppointment(
            startDate: date, barn: barn, horses: [horse], in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: date, completedAt: date.addingTimeInterval(10),
            appointment: appointment, in: context
        )
        let membership = try #require(visit.visitHorses.first)
        membership.outcomeRawValue = VisitOutcome.serviced.rawValue
        membership.workNotes = "Front shoes"
        let work = ModelFixtures.makeWorkItem(
            service: service, visitHorse: membership, in: context
        )
        let photo = Photograph(
            id: UUID(), createdAt: date, pixelWidth: 1200, pixelHeight: 900,
            byteCount: 42, visitHorse: membership
        )
        context.insert(photo)
        membership.photographs.append(photo)
        let invoice = ModelFixtures.makeInvoice(
            number: 16, client: client, businessProfile: profile, in: context
        )
        let group = ModelFixtures.makeInvoiceVisit(
            invoice: invoice, sourceVisit: visit, in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: group, sourceWorkItem: work, in: context
        )
        let payment = Payment(
            amountMinorUnits: 12_500, currencyCode: "GBP", receivedAt: date,
            method: .cheque, reference: "CHEQUE-16", invoice: invoice
        )
        context.insert(payment)
        try invoice.recordCompletedPayment(payment)
        try DomainGraphValidator.save(context)
        return container
    }
}
