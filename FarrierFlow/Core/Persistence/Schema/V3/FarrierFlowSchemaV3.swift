import SwiftData

nonisolated enum FarrierFlowSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

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
        ]
    }
}
