import Foundation

nonisolated enum ExportFormatV1 {
    static let version = 1
    static let rootDirectory = "FarrierFlow Export"

    static func invoicePDFRelativePath(number: Int64) -> String {
        let decimal = String(number)
        let padding = String(repeating: "0", count: max(0, 4 - decimal.count))
        return "Invoices/Invoice-\(padding)\(decimal).pdf"
    }

    static let csvDefinitions: [ExportCSVDefinition] = [
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
    ]
}

nonisolated enum ExportEntity: String, Sendable, CaseIterable {
    case businessProfile = "business-profile"
    case client
    case serviceLocation = "service-location"
    case horse
    case appointment
    case appointmentHorse = "appointment-horse"
    case visit
    case visitHorse = "visit-horse"
    case photograph
    case service
    case workItem = "work-item"
    case invoice
    case invoiceVisit = "invoice-visit"
    case invoiceLineItem = "invoice-line-item"
}

nonisolated struct ExportRecordID: Sendable, Hashable, Equatable {
    let entity: ExportEntity
    let ordinal: Int

    init(entity: ExportEntity, ordinal: Int) throws {
        guard ordinal > 0 else {
            throw ExportFormatError.invalidExportRecordOrdinal(ordinal)
        }
        self.entity = entity
        self.ordinal = ordinal
    }

    var value: String {
        let decimal = String(ordinal)
        let padding = String(repeating: "0", count: max(0, 6 - decimal.count))
        return "\(entity.rawValue)-\(padding)\(decimal)"
    }
}

nonisolated struct ExportCSVDefinition: Sendable, Equatable {
    let relativePath: String
    let columns: [String]
}
