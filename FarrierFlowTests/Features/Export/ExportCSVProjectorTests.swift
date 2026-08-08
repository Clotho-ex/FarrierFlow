import Foundation
import Testing
@testable import FarrierFlow

@Suite("Export CSV projector")
struct ExportCSVProjectorTests {
    @Test func formatsCanonicalAndInformationalScalarValues() {
        let date = Date(timeIntervalSince1970: 1_725_000_000.123456)
        let context = ExportContext(
            createdAt: date,
            localeIdentifier: "en_US_POSIX",
            calendarIdentifier: .gregorian,
            timeZoneIdentifier: "America/New_York"
        )

        #expect(ExportValueFormatter.utc(date) == "2024-08-30T06:40:00.123456Z")
        #expect(ExportValueFormatter.local(date, context: context) == "2024-08-30T02:40:00.123456-04:00")
        #expect(ExportValueFormatter.boolean(true) == "true")
        #expect(ExportValueFormatter.boolean(false) == "false")
        #expect(ExportValueFormatter.usdDisplay(minorUnits: 0, localeIdentifier: "en_US") == "$0.00")
        #expect(ExportValueFormatter.usdDisplay(minorUnits: 1_234_567_890, localeIdentifier: "en_US") == "$12,345,678.90")
        #expect(ExportValueFormatter.usdDisplay(minorUnits: 123_456, localeIdentifier: "de_DE") == "1.234,56\u{00A0}$")
    }

    @Test func projectsEveryVersionOneTableWithExactWidthsAndOptionalEmpties() throws {
        let tables = try ExportCSVProjector.tables(
            from: Self.snapshot(),
            photographResults: [Self.photographUUID: .copied(relativePath: "Photographs/01234567-89ab-cdef-0123-456789abcdef.jpg", byteCount: 42)]
        )

        #expect(tables.map(\.definition.relativePath) == ExportFormatV1.csvDefinitions.map(\.relativePath))
        #expect(tables.allSatisfy { table in table.rows.allSatisfy { $0.count == table.definition.columns.count } })
        #expect(tables[0].rows[0] == [.raw("business-profile-000001"), .userText("Farrier = Co"), .userText("555-0100"), .empty, .empty, .empty, .raw("45"), .empty, .raw("7")])
        #expect(tables[1].rows[0] == [.raw("client-000001"), .userText("Client"), .empty, .userText("client@example.com"), .userText("=formula")])
        #expect(tables[2].rows[0] == [.raw("service-location-000001"), .userText("North Field"), .empty, .userText("Gate code")])
        #expect(tables[3].rows[0] == [.raw("horse-000001"), .userText("Milo"), .empty, .raw("6"), .raw("client-000001"), .raw("service-location-000001"), .empty])
        #expect(tables[4].rows[0] == [.raw("appointment-000001"), .raw("2024-08-30T06:40:00.123456Z"), .raw("2024-08-30T02:40:00.123456-04:00"), .empty, .raw("60"), .raw("service-location-000001")])
        #expect(tables[5].rows[0] == [.raw("appointment-horse-000001"), .raw("appointment-000001"), .raw("horse-000001")])
        #expect(tables[6].rows[0] == [.raw("visit-000001"), .raw("2024-08-30T06:40:00.123456Z"), .raw("2024-08-30T02:40:00.123456-04:00"), .empty, .empty, .userText("North Field"), .empty, .raw("appointment-000001"), .raw("service-location-000001")])
        #expect(tables[7].rows[0] == [.raw("visit-horse-000001"), .raw("serviced"), .userText("Done"), .raw("visit-000001"), .raw("horse-000001")])
        #expect(tables[8].rows[0] == [.raw("photograph-000001"), .raw("01234567-89ab-cdef-0123-456789abcdef"), .raw("2024-08-30T06:40:00.123456Z"), .raw("2024-08-30T02:40:00.123456-04:00"), .raw("1200"), .raw("900"), .raw("42"), .raw("visit-horse-000001"), .raw("available"), .raw("Photographs/01234567-89ab-cdef-0123-456789abcdef.jpg")])
        #expect(tables[9].rows[0] == [.raw("service-000001"), .userText("Trim"), .raw("12500"), .raw("USD"), .raw("$\u{00A0}125.00"), .raw("false")])
        #expect(tables[10].rows[0] == [.raw("work-item-000001"), .userText("Trim"), .raw("12500"), .raw("USD"), .raw("$\u{00A0}125.00"), .raw("service-000001"), .raw("visit-horse-000001"), .empty])
        #expect(tables[11].rows[0] == [.raw("invoice-000001"), .raw("7"), .raw("2024-08-30T06:40:00.123456Z"), .raw("2024-08-30T02:40:00.123456-04:00"), .empty, .empty, .empty, .raw("paid"), .raw("2024-08-30T06:40:00.123456Z"), .raw("2024-08-30T02:40:00.123456-04:00"), .userText("Client"), .empty, .empty, .userText("Farrier = Co"), .empty, .empty, .empty, .raw("USD"), .raw("client-000001"), .raw("Invoices/Invoice-0007.pdf")])
        #expect(tables[12].rows[0] == [.raw("invoice-visit-000001"), .raw("2024-08-30T06:40:00.123456Z"), .raw("2024-08-30T02:40:00.123456-04:00"), .userText("North Field"), .empty, .raw("invoice-000001"), .raw("visit-000001")])
        #expect(tables[13].rows[0] == [.raw("invoice-line-item-000001"), .userText("Milo"), .userText("Trim"), .raw("12500"), .raw("USD"), .raw("$\u{00A0}125.00"), .raw("invoice-visit-000001"), .raw("work-item-000001")])

        let encodedClients = try #require(String(data: ExportCSVWriter().encode(tables[1]), encoding: .utf8))
        #expect(encodedClients.contains("'=formula"))
    }

    @Test func emitsHeaderOnlyTablesForAnEmptySnapshot() throws {
        let empty = ExportSnapshot(
            context: Self.context,
            businessProfiles: [], clients: [], serviceLocations: [], horses: [], appointments: [], appointmentHorses: [], visits: [], visitHorses: [], photographs: [], services: [], workItems: [], invoices: [], invoiceVisits: [], invoiceLineItems: [], invoiceDocuments: []
        )

        let tables = try ExportCSVProjector.tables(from: empty, photographResults: [:])

        #expect(tables.count == 14)
        #expect(tables.allSatisfy { $0.rows.isEmpty })
    }

    @Test func preservesPersistedInt64InvoiceNumbersWithoutNarrowing() throws {
        let snapshot = try Self.snapshot(nextInvoiceNumber: .max, invoiceNumber: .max)
        let businessProfileNextInvoiceNumber: Int64 = snapshot.businessProfiles[0].nextInvoiceNumber
        let invoiceNumber: Int64 = snapshot.invoices[0].number

        #expect(businessProfileNextInvoiceNumber == .max)
        #expect(invoiceNumber == .max)

        let tables = try ExportCSVProjector.tables(from: snapshot, photographResults: [Self.photographUUID: .unavailable])

        #expect(tables[0].rows[0][8] == .raw("9223372036854775807"))
        #expect(tables[11].rows[0][1] == .raw("9223372036854775807"))
    }

    @Test func derivesInvoicePDFPathFromTheImmutableInvoiceNumber() throws {
        let tables = try ExportCSVProjector.tables(
            from: Self.snapshot(invoiceNumber: 42),
            photographResults: [Self.photographUUID: .unavailable]
        )

        #expect(tables[11].rows[0][19] == .raw("Invoices/Invoice-0042.pdf"))
    }

    @Test func projectsUnavailablePhotographsAndRejectsInvalidExportValues() throws {
        let unavailable = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .unavailable])
        #expect(unavailable[8].rows[0][8...] == [.raw("unavailable"), .empty])

        #expect(throws: ExportFormatError.missingPhotographResult(Self.photographUUID)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [:])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "", byteCount: 42)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "", byteCount: 42)])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "Photographs/file.jpg", byteCount: 41)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "Photographs/file.jpg", byteCount: 41)])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "Photographs/file.jpg", byteCount: -1)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "Photographs/file.jpg", byteCount: -1)])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "/Photographs/file.jpg", byteCount: 42)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "/Photographs/file.jpg", byteCount: 42)])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "Photographs/../file.jpg", byteCount: 42)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "Photographs/../file.jpg", byteCount: 42)])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "Data/clients.csv", byteCount: 42)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "Data/clients.csv", byteCount: 42)])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "Photographs/01234567-89ab-cdef-0123-456789abcdee.jpg", byteCount: 42)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "Photographs/01234567-89ab-cdef-0123-456789abcdee.jpg", byteCount: 42)])
        }
        #expect(throws: ExportFormatError.invalidPhotographCopy(relativePath: "Photographs/01234567-89ab-cdef-0123-456789abcdef.png", byteCount: 42)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(), photographResults: [Self.photographUUID: .copied(relativePath: "Photographs/01234567-89ab-cdef-0123-456789abcdef.png", byteCount: 42)])
        }
        #expect(throws: ExportFormatError.unsupportedVisitOutcome("unknown")) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(outcome: "unknown"), photographResults: [Self.photographUUID: .unavailable])
        }
        #expect(throws: ExportFormatError.unsupportedInvoiceStatus("unknown")) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(status: "unknown"), photographResults: [Self.photographUUID: .unavailable])
        }
        #expect(throws: ExportFormatError.unsupportedCurrencyCode("EUR")) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(currencyCode: "EUR"), photographResults: [Self.photographUUID: .unavailable])
        }
        #expect(throws: ExportFormatError.invalidMonetaryValue(-1)) {
            _ = try ExportCSVProjector.tables(from: Self.snapshot(minorUnits: -1), photographResults: [Self.photographUUID: .unavailable])
        }
    }

    @Test func projectsEverySupportedVisitOutcomeAndInvoiceStatus() throws {
        for outcome in ["pending", "serviced", "notServiced"] {
            let tables = try ExportCSVProjector.tables(from: Self.snapshot(outcome: outcome), photographResults: [Self.photographUUID: .unavailable])
            #expect(tables[7].rows[0][1] == .raw(outcome))
        }
        for status in ["unpaid", "paid"] {
            let tables = try ExportCSVProjector.tables(from: Self.snapshot(status: status), photographResults: [Self.photographUUID: .unavailable])
            #expect(tables[11].rows[0][7] == .raw(status))
        }
    }

    private static let date = Date(timeIntervalSince1970: 1_725_000_000.123456)
    private static let photographUUID = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
    private static let context = ExportContext(createdAt: date, localeIdentifier: "en_US_POSIX", calendarIdentifier: .gregorian, timeZoneIdentifier: "America/New_York")

    private static func id(_ entity: ExportEntity) throws -> ExportRecordID {
        try .init(entity: entity, ordinal: 1)
    }

    private static func snapshot(outcome: String = "serviced", status: String = "paid", currencyCode: String = "USD", minorUnits: Int64 = 12_500, nextInvoiceNumber: Int64 = 7, invoiceNumber: Int64 = 7) throws -> ExportSnapshot {
        let businessProfile = try id(.businessProfile), client = try id(.client), location = try id(.serviceLocation), horse = try id(.horse), appointment = try id(.appointment), appointmentHorse = try id(.appointmentHorse), visit = try id(.visit), visitHorse = try id(.visitHorse), photograph = try id(.photograph), service = try id(.service), workItem = try id(.workItem), invoice = try id(.invoice), invoiceVisit = try id(.invoiceVisit), invoiceLineItem = try id(.invoiceLineItem)
        return .init(
            context: context,
            businessProfiles: [.init(id: businessProfile, name: "Farrier = Co", phone: "555-0100", email: nil, address: nil, defaultInvoiceNote: nil, defaultAppointmentDurationMinutes: 45, defaultInvoiceDueDays: nil, nextInvoiceNumber: nextInvoiceNumber)],
            clients: [.init(id: client, name: "Client", phone: nil, email: "client@example.com", notes: "=formula")],
            serviceLocations: [.init(id: location, name: "North Field", address: nil, contactNotes: "Gate code")],
            horses: [.init(id: horse, name: "Milo", safetyNotes: nil, appointmentIntervalWeeks: 6, clientID: client, currentServiceLocationID: location, defaultServiceID: nil)],
            appointments: [.init(id: appointment, startDate: date, notes: nil, expectedDurationMinutes: 60, serviceLocationID: location)],
            appointmentHorses: [.init(id: appointmentHorse, appointmentID: appointment, horseID: horse)],
            visits: [.init(id: visit, startedAt: date, completedAt: nil, serviceLocationNameSnapshot: "North Field", serviceLocationAddressSnapshot: nil, appointmentID: appointment, serviceLocationID: location)],
            visitHorses: [.init(id: visitHorse, outcomeRawValue: outcome, workNotes: "Done", visitID: visit, horseID: horse)],
            photographs: [.init(id: photograph, photographID: photographUUID, createdAt: date, pixelWidth: 1200, pixelHeight: 900, byteCount: 42, visitHorseID: visitHorse)],
            services: [.init(id: service, name: "Trim", defaultAmountMinorUnits: minorUnits, currencyCode: currencyCode, isArchived: false)],
            workItems: [.init(id: workItem, serviceNameSnapshot: "Trim", amountMinorUnits: minorUnits, currencyCode: currencyCode, serviceID: service, visitHorseID: visitHorse, invoiceLineItemID: nil)],
            invoices: [.init(id: invoice, number: invoiceNumber, invoiceDate: date, dueDate: nil, note: nil, statusRawValue: status, paidAt: date, clientNameSnapshot: "Client", clientPhoneSnapshot: nil, clientEmailSnapshot: nil, businessNameSnapshot: "Farrier = Co", businessPhoneSnapshot: nil, businessEmailSnapshot: nil, businessAddressSnapshot: nil, currencyCode: currencyCode, clientID: client)],
            invoiceVisits: [.init(id: invoiceVisit, visitDateSnapshot: date, serviceLocationNameSnapshot: "North Field", serviceLocationAddressSnapshot: nil, invoiceID: invoice, sourceVisitID: visit)],
            invoiceLineItems: [.init(id: invoiceLineItem, horseNameSnapshot: "Milo", serviceNameSnapshot: "Trim", amountMinorUnits: minorUnits, currencyCode: currencyCode, invoiceVisitID: invoiceVisit, sourceWorkItemID: workItem)],
            invoiceDocuments: []
        )
    }
}
