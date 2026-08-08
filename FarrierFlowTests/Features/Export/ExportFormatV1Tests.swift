import Testing
@testable import FarrierFlow

@Suite("Export format version 1")
struct ExportFormatV1Tests {
    @Test func definesEveryVersionOneTableInClosedOrder() {
        #expect(ExportFormatV1.version == 1)
        #expect(ExportFormatV1.rootDirectory == "FarrierFlow Export")
        #expect(ExportFormatV1.csvDefinitions == [
            .init(relativePath: "Data/business-profile.csv", columns: ["export_id", "name", "phone", "email", "address", "default_invoice_note", "default_appointment_duration_minutes", "default_invoice_due_days", "next_invoice_number"]),
            .init(relativePath: "Data/clients.csv", columns: ["export_id", "name", "phone", "email", "notes"]),
            .init(relativePath: "Data/service-locations.csv", columns: ["export_id", "name", "address", "contact_notes"]),
            .init(relativePath: "Data/horses.csv", columns: ["export_id", "name", "safety_notes", "appointment_interval_weeks", "client_id", "current_service_location_id", "default_service_id"]),
            .init(relativePath: "Data/appointments.csv", columns: ["export_id", "start_date_utc", "start_date_local", "notes", "expected_duration_minutes", "service_location_id"]),
            .init(relativePath: "Data/appointment-horses.csv", columns: ["export_id", "appointment_id", "horse_id"]),
            .init(relativePath: "Data/visits.csv", columns: ["export_id", "started_at_utc", "started_at_local", "completed_at_utc", "completed_at_local", "service_location_name_snapshot", "service_location_address_snapshot", "appointment_id", "service_location_id"]),
            .init(relativePath: "Data/visit-horses.csv", columns: ["export_id", "outcome", "work_notes", "visit_id", "horse_id"]),
            .init(relativePath: "Data/photographs.csv", columns: ["export_id", "photograph_uuid", "created_at_utc", "created_at_local", "pixel_width", "pixel_height", "byte_count", "visit_horse_id", "file_status", "file_name"]),
            .init(relativePath: "Data/services.csv", columns: ["export_id", "name", "default_amount_minor_units", "currency_code", "default_amount_display", "is_archived"]),
            .init(relativePath: "Data/work-items.csv", columns: ["export_id", "service_name_snapshot", "amount_minor_units", "currency_code", "amount_display", "service_id", "visit_horse_id", "invoice_line_item_id"]),
            .init(relativePath: "Data/invoices.csv", columns: ["export_id", "number", "invoice_date_utc", "invoice_date_local", "due_date_utc", "due_date_local", "note", "status", "paid_at_utc", "paid_at_local", "client_name_snapshot", "client_phone_snapshot", "client_email_snapshot", "business_name_snapshot", "business_phone_snapshot", "business_email_snapshot", "business_address_snapshot", "currency_code", "client_id", "pdf_file_name"]),
            .init(relativePath: "Data/invoice-visits.csv", columns: ["export_id", "visit_date_snapshot_utc", "visit_date_snapshot_local", "service_location_name_snapshot", "service_location_address_snapshot", "invoice_id", "source_visit_id"]),
            .init(relativePath: "Data/invoice-line-items.csv", columns: ["export_id", "horse_name_snapshot", "service_name_snapshot", "amount_minor_units", "currency_code", "amount_display", "invoice_visit_id", "source_work_item_id"]),
        ])
    }

    @Test func derivesCanonicalInvoicePDFPathsWithoutNarrowingOrTruncation() {
        #expect(ExportFormatV1.invoicePDFRelativePath(number: 7) == "Invoices/Invoice-0007.pdf")
        #expect(ExportFormatV1.invoicePDFRelativePath(number: 42) == "Invoices/Invoice-0042.pdf")
        #expect(ExportFormatV1.invoicePDFRelativePath(number: 1_234) == "Invoices/Invoice-1234.pdf")
        #expect(ExportFormatV1.invoicePDFRelativePath(number: 12_345) == "Invoices/Invoice-12345.pdf")
        #expect(ExportFormatV1.invoicePDFRelativePath(number: .max) == "Invoices/Invoice-9223372036854775807.pdf")
    }

    @Test func formatsTypedIDsWithMinimumWidthWithoutTruncatingLargerOrdinals() throws {
        #expect(try ExportRecordID(entity: .client, ordinal: 1).value == "client-000001")
        #expect(try ExportRecordID(entity: .invoiceLineItem, ordinal: 1_234_567).value == "invoice-line-item-1234567")
        #expect(try ExportRecordID(entity: .client, ordinal: Int(Int32.max) + 1).value == "client-2147483648")
        #expect(try ExportRecordID(entity: .client, ordinal: Int.max).value == "client-9223372036854775807")
    }

    @Test func rejectsNonpositiveExportRecordOrdinals() {
        #expect(throws: ExportFormatError.invalidExportRecordOrdinal(0)) {
            _ = try ExportRecordID(entity: .client, ordinal: 0)
        }
        #expect(throws: ExportFormatError.invalidExportRecordOrdinal(-1)) {
            _ = try ExportRecordID(entity: .client, ordinal: -1)
        }
    }
}
