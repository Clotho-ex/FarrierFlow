import Foundation

nonisolated struct ExportContext: Sendable, Equatable {
    let createdAt: Date
    let localeIdentifier: String
    let calendarIdentifier: Calendar.Identifier
    let timeZoneIdentifier: String
}

nonisolated struct BusinessProfileExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let name: String
    let phone: String?
    let email: String?
    let address: String?
    let defaultInvoiceNote: String?
    let defaultAppointmentDurationMinutes: Int?
    let defaultInvoiceDueDays: Int?
    let nextInvoiceNumber: Int64
}

nonisolated struct ClientExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let name: String
    let phone: String?
    let email: String?
    let notes: String?
}

nonisolated struct ServiceLocationExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let name: String
    let address: String?
    let contactNotes: String?
}

nonisolated struct HorseExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let name: String
    let safetyNotes: String?
    let appointmentIntervalWeeks: Int
    let clientID: ExportRecordID
    let currentServiceLocationID: ExportRecordID
    let defaultServiceID: ExportRecordID?
}

nonisolated struct AppointmentExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let startDate: Date
    let notes: String?
    let expectedDurationMinutes: Int?
    let serviceLocationID: ExportRecordID
}

nonisolated struct AppointmentHorseExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let appointmentID: ExportRecordID
    let horseID: ExportRecordID
}

nonisolated struct VisitExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let startedAt: Date
    let completedAt: Date?
    let serviceLocationNameSnapshot: String
    let serviceLocationAddressSnapshot: String?
    let appointmentID: ExportRecordID
    let serviceLocationID: ExportRecordID
}

nonisolated struct VisitHorseExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let outcomeRawValue: String
    let workNotes: String?
    let visitID: ExportRecordID
    let horseID: ExportRecordID
}

nonisolated struct PhotographExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let photographID: UUID
    let createdAt: Date
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int64
    let visitHorseID: ExportRecordID
}

nonisolated struct ServiceExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let name: String
    let defaultAmountMinorUnits: Int64
    let currencyCode: String
    let isArchived: Bool
}

nonisolated struct WorkItemExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let serviceNameSnapshot: String
    let amountMinorUnits: Int64
    let currencyCode: String
    let serviceID: ExportRecordID
    let visitHorseID: ExportRecordID
    let invoiceLineItemID: ExportRecordID?
}

nonisolated struct InvoiceExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let number: Int64
    let invoiceDate: Date
    let dueDate: Date?
    let note: String?
    let statusRawValue: String
    let paidAt: Date?
    let clientNameSnapshot: String
    let clientPhoneSnapshot: String?
    let clientEmailSnapshot: String?
    let businessNameSnapshot: String
    let businessPhoneSnapshot: String?
    let businessEmailSnapshot: String?
    let businessAddressSnapshot: String?
    let currencyCode: String
    let clientID: ExportRecordID
    let pdfFileName: String
}

nonisolated struct InvoiceVisitExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let visitDateSnapshot: Date
    let serviceLocationNameSnapshot: String
    let serviceLocationAddressSnapshot: String?
    let invoiceID: ExportRecordID
    let sourceVisitID: ExportRecordID
}

nonisolated struct InvoiceLineItemExportRecord: Sendable, Equatable {
    let id: ExportRecordID
    let horseNameSnapshot: String
    let serviceNameSnapshot: String
    let amountMinorUnits: Int64
    let currencyCode: String
    let invoiceVisitID: ExportRecordID
    let sourceWorkItemID: ExportRecordID
}

nonisolated struct ExportInvoiceDocument: Sendable, Equatable {
    let invoiceID: ExportRecordID
    let relativePath: String
    let content: InvoicePDFContent
}

nonisolated enum PhotographExportFileResult: Sendable, Equatable {
    case copied(relativePath: String, byteCount: Int64)
    case unavailable
}

nonisolated struct ExportSnapshot: Sendable, Equatable {
    let context: ExportContext
    let businessProfiles: [BusinessProfileExportRecord]
    let clients: [ClientExportRecord]
    let serviceLocations: [ServiceLocationExportRecord]
    let horses: [HorseExportRecord]
    let appointments: [AppointmentExportRecord]
    let appointmentHorses: [AppointmentHorseExportRecord]
    let visits: [VisitExportRecord]
    let visitHorses: [VisitHorseExportRecord]
    let photographs: [PhotographExportRecord]
    let services: [ServiceExportRecord]
    let workItems: [WorkItemExportRecord]
    let invoices: [InvoiceExportRecord]
    let invoiceVisits: [InvoiceVisitExportRecord]
    let invoiceLineItems: [InvoiceLineItemExportRecord]
    let invoiceDocuments: [ExportInvoiceDocument]
}
