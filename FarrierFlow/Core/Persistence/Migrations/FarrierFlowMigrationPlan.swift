import SwiftData

nonisolated enum FarrierFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            FarrierFlowSchemaV1.self,
            FarrierFlowSchemaV2.self,
            FarrierFlowSchemaV3.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: FarrierFlowSchemaV1.self,
                toVersion: FarrierFlowSchemaV2.self
            ),
            .lightweight(
                fromVersion: FarrierFlowSchemaV2.self,
                toVersion: FarrierFlowSchemaV3.self
            ),
        ]
    }
}
