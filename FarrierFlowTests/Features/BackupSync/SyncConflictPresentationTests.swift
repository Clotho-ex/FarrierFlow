import Foundation
import Testing
@testable import FarrierFlow

@Suite("Conflict review values")
struct SyncConflictPresentationTests {
    @Test
    @MainActor
    func unchangedNamesIdentifyConflictsEvenWhenOnlyPhoneOrNotesDiffer() {
        let client = SyncRecord(id: UUID(), kind: .client,
            fields: ["name": .string("Jordan Ellis"), "phone": .string("555-0148")])
        let horse = SyncRecord(id: UUID(), kind: .horse,
            fields: ["name": .string("Atlas"), "notes": .string("Needs care")])
        #expect(SyncConflictPresentation.identity(client, graph: [], locale: .current) == "Jordan Ellis")
        #expect(SyncConflictPresentation.identity(horse, graph: [], locale: .current) == "Atlas")
        let missing = SyncRecord(id: UUID(), kind: .payment, fields: [:])
        #expect(SyncConflictPresentation.identity(missing, graph: [], locale: .current) == missing.id.uuidString)
    }

    @Test
    @MainActor
    func appointmentAndIssuedInvoiceIdentitiesUseTheirOwnRecordedValues() {
        let barn = SyncRecord(id: UUID(), kind: .barn, fields: ["name": .string("North Field")])
        let appointment = SyncRecord(id: UUID(), kind: .appointment,
            fields: ["barn": .string(barn.id.uuidString), "startDate": .string("813456789")])
        let title = SyncConflictPresentation.identity(appointment, graph: [barn], locale: Locale(identifier: "en_US"))
        #expect(title.contains("North Field") && title.contains("2026"))
        let invoice = SyncRecord(id: UUID(), kind: .invoice,
            fields: ["number": .integer(148), "clientNameSnapshot": .string("Original Client")])
        #expect(SyncConflictPresentation.identity(invoice, graph: [], locale: Locale(identifier: "en_US")) == "Invoice 0148 · Original Client")
    }
    @Test
    func moneyUsesRecordedCurrencyAndDoesNotGuessMissingCurrency() {
        let locale = Locale(identifier: "en_GB")
        let record = SyncRecord(id: UUID(), kind: .workItem,
            fields: ["amountMinorUnits": .integer(2599), "currencyCode": .string("GBP")])
        #expect(SyncConflictPresentation.value(record.fields["amountMinorUnits"], key: "amountMinorUnits",
            record: record, graph: [], locale: locale) == "£25.99")
        let missing = SyncRecord(id: record.id, kind: .workItem, fields: ["amountMinorUnits": .integer(2599)])
        #expect(SyncConflictPresentation.value(missing.fields["amountMinorUnits"], key: "amountMinorUnits",
            record: missing, graph: [], locale: locale) == String(localized: "Unavailable"))
    }

    @Test
    func referencesShowTheRelatedRecordRatherThanGuessingIdentity() {
        let parent = SyncRecord(id: UUID(), kind: .client, fields: ["name": .string("Pat")])
        let horse = SyncRecord(id: UUID(), kind: .horse, fields: ["client": .string(parent.id.uuidString)])
        #expect(SyncConflictPresentation.value(horse.fields["client"], key: "client", record: horse,
            graph: [parent], locale: .current) == "Pat")
        #expect(SyncConflictPresentation.value(horse.fields["client"], key: "client", record: horse,
            graph: [], locale: .current) == parent.id.uuidString)
        let service = SyncRecord(id: UUID(), kind: .service, fields: ["name": .string("Trim")])
        let plan = SyncRecord(id: UUID(), kind: .appointmentHorse, fields: ["plannedService": .string(service.id.uuidString)])
        #expect(SyncConflictPresentation.value(plan.fields["plannedService"], key: "plannedService", record: plan,
            graph: [service], locale: .current) == "Trim")
        #expect(SyncConflictPresentation.titles["plannedService"] != nil)
    }

    @Test
    func invalidDatesNeverBecomeAConvincingFormattedDate() {
        let visit = SyncRecord(id: UUID(), kind: .visit, fields: ["startedAt": .string("nan")])
        #expect(SyncConflictPresentation.value(visit.fields["startedAt"], key: "startedAt",
            record: visit, graph: [], locale: .current) == String(localized: "Unavailable"))
    }
}
