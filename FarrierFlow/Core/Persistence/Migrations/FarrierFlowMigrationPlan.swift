import SwiftData

nonisolated enum FarrierFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FarrierFlowSchemaV1.self, FarrierFlowSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: FarrierFlowSchemaV1.self,
                toVersion: FarrierFlowSchemaV2.self
            ),
        ]
    }
}
