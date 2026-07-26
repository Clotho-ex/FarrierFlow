import SwiftData

nonisolated enum FarrierFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FarrierFlowSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
