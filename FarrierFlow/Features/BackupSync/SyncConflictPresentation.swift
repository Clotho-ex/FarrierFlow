import Foundation

nonisolated enum SyncConflictPresentation {
    static let titles: [String: LocalizedStringResource] = [
        "name": "Name", "phone": "Phone", "email": "Email", "address": "Address",
        "notes": "Notes", "contactNotes": "Contact Notes", "safetyNotes": "Safety Notes",
        "defaultInvoiceNote": "Default Invoice Note", "defaultAppointmentDurationMinutes": "Appointment duration (minutes)",
        "defaultInvoiceDueDays": "Invoice due after (days)", "nextInvoiceNumber": "Next Invoice Number",
        "currencyCode": "Currency", "defaultAmountMinorUnits": "Default Price", "amountMinorUnits": "Amount",
        "isArchived": "Archived", "appointmentIntervalWeeks": "Appointment interval (weeks)",
        "client": "Client", "currentBarn": "Current Service Location", "defaultService": "Default Service", "plannedService": "Planned Service",
        "startDate": "Appointment date", "expectedDurationMinutes": "Expected duration (minutes)",
        "barn": "Service Location", "appointment": "Appointment", "horse": "Horse", "visit": "Visit",
        "visitHorse": "Horse’s Visit", "startedAt": "Started", "completedAt": "Completed",
        "serviceLocationNameSnapshot": "Recorded service location", "serviceLocationAddressSnapshot": "Recorded location address",
        "outcomeRawValue": "Work Status", "workNotes": "Work Notes", "createdAt": "Photo date",
        "pixelWidth": "Photo width (pixels)", "pixelHeight": "Photo height (pixels)", "byteCount": "Photo size (bytes)",
        "serviceNameSnapshot": "Recorded service", "service": "Service", "number": "Invoice Number",
        "invoiceDate": "Invoice Date", "dueDate": "Due Date", "note": "Note", "statusRawValue": "Status",
        "clientNameSnapshot": "Recorded client name", "clientPhoneSnapshot": "Recorded client phone",
        "clientEmailSnapshot": "Recorded client email", "businessNameSnapshot": "Recorded business name",
        "businessPhoneSnapshot": "Recorded business phone", "businessEmailSnapshot": "Recorded business email",
        "businessAddressSnapshot": "Recorded business address", "visitDateSnapshot": "Recorded visit date",
        "invoice": "Invoice", "sourceVisit": "Original Visit", "invoiceVisit": "Invoice Visit",
        "sourceWorkItem": "Original Work", "horseNameSnapshot": "Recorded horse name", "receivedAt": "Received",
        "methodRawValue": "Payment Method", "sourceRawValue": "Payment Source", "otherDescription": "Payment Description",
        "reference": "Reference"
    ]
    private static let dates: Set<String> = ["startDate", "startedAt", "completedAt", "createdAt", "invoiceDate", "dueDate", "visitDateSnapshot", "receivedAt"]
    private static let references: Set<String> = ["client", "currentBarn", "defaultService", "plannedService", "barn", "appointment", "horse", "visit", "visitHorse", "service", "invoice", "sourceVisit", "invoiceVisit", "sourceWorkItem"]

    @MainActor
    static func identity(_ record: SyncRecord, graph: [SyncRecord], locale: Locale) -> String {
        func text(_ key: String) -> String? {
            guard case .string(let value) = record.fields[key], !value.isEmpty else { return nil }
            return value
        }
        if let name = text("name") { return name }
        if record.kind == .invoice, case .integer(let number) = record.fields["number"],
           let formatted = try? InvoiceDomainRules.formattedNumber(number) {
            let invoice = String(localized: "Invoice \(formatted)", locale: locale)
            return [invoice, text("clientNameSnapshot")].compactMap { $0 }.joined(separator: " · ")
        }
        if let name = text("horseNameSnapshot") ?? text("serviceNameSnapshot") { return name }
        if let horse = relatedName("horse", record: record, graph: graph) { return horse }
        let dateKey = record.kind == .appointment ? "startDate" : "startedAt"
        if let rawDate = text(dateKey), let seconds = Double(rawDate), seconds.isFinite, abs(seconds) <= 1e12 {
            let date = Date(timeIntervalSinceReferenceDate: seconds)
                .formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(locale))
            let location = text("serviceLocationNameSnapshot") ?? relatedName("barn", record: record, graph: graph)
            return [location, date].compactMap { $0 }.joined(separator: " · ")
        }
        // Unnamed or missing relationships retain an exact, distinguishable identity.
        return record.id.uuidString
    }

    private static func relatedName(_ key: String, record: SyncRecord, graph: [SyncRecord]) -> String? {
        guard case .string(let rawID) = record.fields[key], let id = UUID(uuidString: rawID),
              let related = graph.first(where: { $0.id == id }),
              case .string(let name) = related.fields["name"], !name.isEmpty else { return nil }
        return name
    }

    static func value(_ value: SyncValue?, key: String, record: SyncRecord?, graph: [SyncRecord], locale: Locale) -> String {
        guard let record else { return String(localized: "Deleted") }
        switch value {
        case .none, .null: return String(localized: "Not set")
        case .boolean(let value): return value ? String(localized: "Yes") : String(localized: "No")
        case .integer(let amount):
            if key.hasSuffix("AmountMinorUnits") || key == "amountMinorUnits" {
                guard case .string(let code) = record.fields["currencyCode"],
                      let formatted = MoneyFormatter.currency(minorUnits: amount, currencyCode: code, locale: locale) else {
                    return String(localized: "Unavailable")
                }
                return formatted
            }
            return amount.formatted(.number.locale(locale))
        case .string(let text):
            if dates.contains(key) {
                guard let seconds = Double(text), seconds.isFinite, abs(seconds) <= 1e12 else {
                    return String(localized: "Unavailable")
                }
                return Date(timeIntervalSinceReferenceDate: seconds)
                    .formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(locale))
            }
            if references.contains(key), let id = UUID(uuidString: text) {
                if let related = graph.first(where: { $0.id == id }), case .string(let name) = related.fields["name"] {
                    return name
                }
                return id.uuidString
            }
            if key == "outcomeRawValue", let outcome = VisitOutcome(rawValue: text) { return String(localized: outcome.localizedTitle) }
            if key == "statusRawValue", let status = InvoiceStatus(rawValue: text) { return status.displayName }
            if key == "methodRawValue", let method = PaymentMethod(rawValue: text) { return method.displayName }
            if key == "sourceRawValue", text == "manual" { return String(localized: "Recorded manually") }
            return text
        }
    }
}

extension SyncRecordKind {
    nonisolated var localizedTitle: LocalizedStringResource {
        switch self {
        case .businessProfile: "My Business"
        case .client: "Client"
        case .barn: "Service Location"
        case .service: "Service"
        case .horse: "Horse"
        case .appointment: "Appointment"
        case .appointmentHorse: "Scheduled Horse"
        case .visit: "Visit"
        case .visitHorse: "Horse’s Visit"
        case .photograph: "Photo"
        case .workItem: "Work"
        case .invoice: "Invoice"
        case .invoiceVisit: "Invoice Visit"
        case .invoiceLineItem: "Invoice Line"
        case .payment: "Payment"
        }
    }
}
