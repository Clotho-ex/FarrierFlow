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
    private let dependenciesResult: Result<AppDependencies, Error>

    init() {
        dependenciesResult = Result {
            #if DEBUG
            if let storeURL = UITestLaunchConfiguration().storeURL {
                try FileManager.default.createDirectory(
                    at: storeURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
                return AppDependencies(
                    container: container,
                    photographLibrary: PhotographLibrary(
                        container: container,
                        fileStore: PhotographFileStore(
                            rootURL: storeURL
                                .deletingPathExtension()
                                .appending(
                                    path: PhotographConstants.rootDirectoryName,
                                    directoryHint: .isDirectory
                                )
                        )
                    )
                )
            }
            #endif
            let container = try ModelContainerFactory.production()
            let applicationSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return AppDependencies(
                container: container,
                photographLibrary: PhotographLibrary(
                    container: container,
                    fileStore: PhotographFileStore(
                        applicationSupportURL: applicationSupportURL
                    )
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            switch dependenciesResult {
            case .success(let dependencies):
                RootView()
                    .modelContainer(dependencies.container)
                    .environment(dependencies.photographLibrary)
            case .failure:
                ModelContainerFailureView()
            }
        }
    }
}

@MainActor
private struct AppDependencies {
    let container: ModelContainer
    let photographLibrary: PhotographLibrary
}
