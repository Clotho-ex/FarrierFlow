import SwiftData

nonisolated enum FarrierFlowSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Client.self, Barn.self, Horse.self, Appointment.self,
            AppointmentHorse.self, Visit.self, VisitHorse.self, Photograph.self,
            Service.self, WorkItem.self, BusinessProfile.self, Invoice.self,
            InvoiceVisit.self, InvoiceLineItem.self, Payment.self, SyncState.self,
        ]
    }
}
