import SwiftData

nonisolated enum FarrierFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            FarrierFlowSchemaV1.self,
            FarrierFlowSchemaV2.self,
            FarrierFlowSchemaV3.self,
            FarrierFlowSchemaV4.self,
            FarrierFlowSchemaV5.self,
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5]
    }

    private static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: FarrierFlowSchemaV1.self,
        toVersion: FarrierFlowSchemaV2.self
    )

    private static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: FarrierFlowSchemaV2.self,
        toVersion: FarrierFlowSchemaV3.self,
        willMigrate: nil,
        didMigrate: { context in
            try SyncRecordIdentity.initializeV3(in: context)
        }
    )

    private static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: FarrierFlowSchemaV3.self,
        toVersion: FarrierFlowSchemaV4.self
    )

    private static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: FarrierFlowSchemaV4.self,
        toVersion: FarrierFlowSchemaV5.self
    )
}
