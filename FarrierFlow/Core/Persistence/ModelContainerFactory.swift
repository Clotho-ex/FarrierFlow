//
//  ModelContainerFactory.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import Foundation
import SwiftData

enum ModelContainerFactory {
    private static let schema = Schema(versionedSchema: FarrierFlowSchemaV2.self)

    static func production() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "FarrierFlowV1",
            schema: schema,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try make(configuration: configuration)
    }

    static func preview() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "FarrierFlowPreview",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let container = try make(configuration: configuration)
        try PreviewFixtures.seed(container.mainContext)
        return container
    }

    static func inMemoryTest() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "FarrierFlowInMemoryTest",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try make(configuration: configuration)
    }

    static func persistentStoreTest(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "FarrierFlowPersistentStoreTest",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try make(configuration: configuration)
    }

    private static func make(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: FarrierFlowMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
