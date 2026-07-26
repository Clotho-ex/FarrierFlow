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
        ]
    }
}
