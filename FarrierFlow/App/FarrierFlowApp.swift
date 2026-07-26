//
//  FarrierFlowApp.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import SwiftData
import SwiftUI

@main
struct FarrierFlowApp: App {
    private let containerResult: Result<ModelContainer, Error>

    init() {
        containerResult = Result {
            #if DEBUG
            if let storeURL = UITestLaunchConfiguration().storeURL {
                try FileManager.default.createDirectory(
                    at: storeURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                return try ModelContainerFactory.persistentStoreTest(at: storeURL)
            }
            #endif
            return try ModelContainerFactory.production()
        }
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure:
                ModelContainerFailureView()
            }
        }
    }
}
