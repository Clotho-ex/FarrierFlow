import SwiftData

nonisolated enum FarrierFlowSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Client.self,
            Barn.self,
            Horse.self,
            Appointment.self,
            AppointmentHorse.self,
            Visit.self,
            VisitHorse.self,
            Photograph.self,
            Service.self,
            WorkItem.self,
            BusinessProfile.self,
            Invoice.self,
            InvoiceVisit.self,
            InvoiceLineItem.self,
        ]
    }
}
