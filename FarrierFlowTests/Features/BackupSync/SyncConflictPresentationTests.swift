import Foundation
import Testing
@testable import FarrierFlow

@Suite("Conflict review values")
struct SyncConflictPresentationTests {
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
    }

    @Test
    func invalidDatesNeverBecomeAConvincingFormattedDate() {
        let visit = SyncRecord(id: UUID(), kind: .visit, fields: ["startedAt": .string("nan")])
        #expect(SyncConflictPresentation.value(visit.fields["startedAt"], key: "startedAt",
            record: visit, graph: [], locale: .current) == String(localized: "Unavailable"))
    }
}
