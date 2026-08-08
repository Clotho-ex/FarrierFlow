import Foundation

nonisolated enum ExportCSVProjector {
    static func tables(
        from snapshot: ExportSnapshot,
        photographResults: [UUID: PhotographExportFileResult]
    ) throws -> [ExportCSVTable] {
        let context = snapshot.context
        let tables: [ExportCSVTable] = [
            table(0, snapshot.businessProfiles.map { record in
                [id(record.id), text(record.name), text(record.phone), text(record.email), text(record.address), text(record.defaultInvoiceNote), integer(record.defaultAppointmentDurationMinutes), integer(record.defaultInvoiceDueDays), integer(record.nextInvoiceNumber)]
            }),
            table(1, snapshot.clients.map { [id($0.id), text($0.name), text($0.phone), text($0.email), text($0.notes)] }),
            table(2, snapshot.serviceLocations.map { [id($0.id), text($0.name), text($0.address), text($0.contactNotes)] }),
            table(3, snapshot.horses.map { [id($0.id), text($0.name), text($0.safetyNotes), integer($0.appointmentIntervalWeeks), id($0.clientID), id($0.currentServiceLocationID), id($0.defaultServiceID)] }),
            table(4, snapshot.appointments.map { [id($0.id)] + dates($0.startDate, context: context) + [text($0.notes), integer($0.expectedDurationMinutes), id($0.serviceLocationID)] }),
            table(5, snapshot.appointmentHorses.map { [id($0.id), id($0.appointmentID), id($0.horseID)] }),
            table(6, snapshot.visits.map { [id($0.id)] + dates($0.startedAt, context: context) + dates($0.completedAt, context: context) + [text($0.serviceLocationNameSnapshot), text($0.serviceLocationAddressSnapshot), id($0.appointmentID), id($0.serviceLocationID)] }),
            table(7, try snapshot.visitHorses.map { [id($0.id), raw(try visitOutcome($0.outcomeRawValue)), text($0.workNotes), id($0.visitID), id($0.horseID)] }),
            table(8, try snapshot.photographs.map { record in
                let result = try photographResult(for: record, in: photographResults)
                return [id(record.id), raw(record.photographID.uuidString), raw(ExportValueFormatter.utc(record.createdAt)), raw(ExportValueFormatter.local(record.createdAt, context: context)), integer(record.pixelWidth), integer(record.pixelHeight), integer(record.byteCount), id(record.visitHorseID), raw(result.status), result.fileName.map(raw) ?? .empty]
            }),
            table(9, try snapshot.services.map { record in
                let display = try moneyDisplay(record.defaultAmountMinorUnits, currencyCode: record.currencyCode, localeIdentifier: context.localeIdentifier)
                return [id(record.id), text(record.name), integer(record.defaultAmountMinorUnits), raw(record.currencyCode), raw(display), raw(ExportValueFormatter.boolean(record.isArchived))]
            }),
            table(10, try snapshot.workItems.map { record in
                let display = try moneyDisplay(record.amountMinorUnits, currencyCode: record.currencyCode, localeIdentifier: context.localeIdentifier)
                return [id(record.id), text(record.serviceNameSnapshot), integer(record.amountMinorUnits), raw(record.currencyCode), raw(display), id(record.serviceID), id(record.visitHorseID), id(record.invoiceLineItemID)]
            }),
            table(11, try snapshot.invoices.map { record in
                [id(record.id), integer(record.number)] + dates(record.invoiceDate, context: context) + dates(record.dueDate, context: context) + [text(record.note), raw(try invoiceStatus(record.statusRawValue))] + dates(record.paidAt, context: context) + [text(record.clientNameSnapshot), text(record.clientPhoneSnapshot), text(record.clientEmailSnapshot), text(record.businessNameSnapshot), text(record.businessPhoneSnapshot), text(record.businessEmailSnapshot), text(record.businessAddressSnapshot), raw(try currency(record.currencyCode)), id(record.clientID), raw(record.pdfFileName)]
            }),
            table(12, snapshot.invoiceVisits.map { [id($0.id)] + dates($0.visitDateSnapshot, context: context) + [text($0.serviceLocationNameSnapshot), text($0.serviceLocationAddressSnapshot), id($0.invoiceID), id($0.sourceVisitID)] }),
            table(13, try snapshot.invoiceLineItems.map { record in
                let display = try moneyDisplay(record.amountMinorUnits, currencyCode: record.currencyCode, localeIdentifier: context.localeIdentifier)
                return [id(record.id), text(record.horseNameSnapshot), text(record.serviceNameSnapshot), integer(record.amountMinorUnits), raw(record.currencyCode), raw(display), id(record.invoiceVisitID), id(record.sourceWorkItemID)]
            }),
        ]
        for table in tables {
            for row in table.rows where row.count != table.definition.columns.count {
                throw ExportFormatError.invalidRowWidth(relativePath: table.definition.relativePath, expected: table.definition.columns.count, actual: row.count)
            }
        }
        return tables
    }

    private static func table(_ definitionIndex: Int, _ rows: [[ExportCSVCell]]) -> ExportCSVTable {
        .init(definition: ExportFormatV1.csvDefinitions[definitionIndex], rows: rows)
    }

    private static func raw(_ value: String) -> ExportCSVCell { .raw(value) }
    private static func text(_ value: String?) -> ExportCSVCell { value.map(ExportCSVCell.userText) ?? .empty }
    private static func integer<T: BinaryInteger>(_ value: T?) -> ExportCSVCell { value.map { .raw(String($0)) } ?? .empty }
    private static func id(_ value: ExportRecordID?) -> ExportCSVCell { value.map { .raw($0.value) } ?? .empty }
    private static func dates(_ value: Date?, context: ExportContext) -> [ExportCSVCell] {
        guard let value else { return [.empty, .empty] }
        return [.raw(ExportValueFormatter.utc(value)), .raw(ExportValueFormatter.local(value, context: context))]
    }

    private static func visitOutcome(_ value: String) throws -> String {
        guard ["pending", "serviced", "notServiced"].contains(value) else { throw ExportFormatError.unsupportedVisitOutcome(value) }
        return value
    }

    private static func invoiceStatus(_ value: String) throws -> String {
        guard ["unpaid", "paid"].contains(value) else { throw ExportFormatError.unsupportedInvoiceStatus(value) }
        return value
    }

    private static func currency(_ value: String) throws -> String {
        guard value == "USD" else { throw ExportFormatError.unsupportedCurrencyCode(value) }
        return value
    }

    private static func moneyDisplay(_ minorUnits: Int64, currencyCode: String, localeIdentifier: String) throws -> String {
        _ = try currency(currencyCode)
        guard minorUnits >= 0, let display = ExportValueFormatter.usdDisplay(minorUnits: minorUnits, localeIdentifier: localeIdentifier) else {
            throw ExportFormatError.invalidMonetaryValue(minorUnits)
        }
        return display
    }

    private static func photographResult(
        for record: PhotographExportRecord,
        in results: [UUID: PhotographExportFileResult]
    ) throws -> (status: String, fileName: String?) {
        guard let result = results[record.photographID] else { throw ExportFormatError.missingPhotographResult(record.photographID) }
        switch result {
        case .unavailable:
            return ("unavailable", nil)
        case let .copied(relativePath, byteCount):
            guard byteCount == record.byteCount, byteCount >= 0, isValidRelativePath(relativePath) else {
                throw ExportFormatError.invalidPhotographCopy(relativePath: relativePath, byteCount: byteCount)
            }
            return ("available", relativePath)
        }
    }

    private static func isValidRelativePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.split(separator: "/").contains("..")
    }
}
