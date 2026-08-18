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
    private let uiTestDynamicTypeSize: DynamicTypeSize?

    init() {
        #if DEBUG
        uiTestDynamicTypeSize = UITestLaunchConfiguration().dynamicTypeSize
        #else
        uiTestDynamicTypeSize = nil
        #endif
        dependenciesResult = Result {
            #if DEBUG
            let uiTestConfiguration = UITestLaunchConfiguration()
            if let storeURL = uiTestConfiguration.storeURL {
                try FileManager.default.createDirectory(
                    at: storeURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
                try uiTestConfiguration.prepare(container)
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
                    .uiTestDynamicTypeSize(uiTestDynamicTypeSize)
            case .failure:
                ModelContainerFailureView()
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func uiTestDynamicTypeSize(_ size: DynamicTypeSize?) -> some View {
        if let size {
            environment(\.dynamicTypeSize, size)
        } else {
            self
        }
    }
}

@MainActor
private struct AppDependencies {
    let container: ModelContainer
    let photographLibrary: PhotographLibrary
}
