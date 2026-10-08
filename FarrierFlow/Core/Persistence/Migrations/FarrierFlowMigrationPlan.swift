import SwiftData

nonisolated enum FarrierFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            FarrierFlowSchemaV1.self,
            FarrierFlowSchemaV2.self,
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    private static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: FarrierFlowSchemaV1.self,
        toVersion: FarrierFlowSchemaV2.self
    )
}
