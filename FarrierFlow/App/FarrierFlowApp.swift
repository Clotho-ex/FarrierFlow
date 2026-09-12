//
//  FarrierFlowApp.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct FarrierFlowApp: App {
    private let dependenciesResult: Result<AppDependencies, Error>
    private let uiTestDynamicTypeSize: DynamicTypeSize?
    private let uiTestColorScheme: ColorScheme?

    init() {
        #if DEBUG
        let uiTestConfiguration = UITestLaunchConfiguration()
        uiTestDynamicTypeSize = uiTestConfiguration.dynamicTypeSize
        uiTestColorScheme = uiTestConfiguration.colorScheme
        #else
        uiTestDynamicTypeSize = nil
        uiTestColorScheme = nil
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
                    analyticsClient: NoOpAnalyticsClient(),
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
                    ),
                    subscriptionAccessModel: SubscriptionAccessModel(
                        client: UITestSubscriptionClient(configuration: uiTestConfiguration)
                    ),
                    onboardingDefaults: uiTestConfiguration.onboardingDefaults
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
                analyticsClient: AnalyticsClientComposition.make(),
                photographLibrary: PhotographLibrary(
                    container: container,
                    fileStore: PhotographFileStore(
                        applicationSupportURL: applicationSupportURL
                    )
                ),
                subscriptionAccessModel: SubscriptionAccessModel(client: Self.subscriptionClient()),
                onboardingDefaults: .standard
            )
        }
    }

    @MainActor
    private static func subscriptionClient() -> any SubscriptionClient {
        guard let key = try? RevenueCatConfiguration.publicSDKKey() else {
            return UnavailableSubscriptionClient()
        }
        return RevenueCatSubscriptionClient(publicSDKKey: key)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch dependenciesResult {
                case .success(let dependencies):
                    RootView(onboardingDefaults: dependencies.onboardingDefaults)
                        .modelContainer(dependencies.container)
                        .environment(\.analyticsClient, dependencies.analyticsClient)
                        .environment(dependencies.photographLibrary)
                        .uiTestDynamicTypeSize(uiTestDynamicTypeSize)
                        .uiTestColorScheme(uiTestColorScheme)
                        .environment(dependencies.subscriptionAccessModel)
                case .failure:
                    ModelContainerFailureView()
                }
            }
            .fontDesign(.rounded)
            .foregroundStyle(ColorTokens.textPrimary)
            .tint(ColorTokens.brandActionText)
            .farrierFlowScreenBackground()
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

    @ViewBuilder
    func uiTestColorScheme(_ colorScheme: ColorScheme?) -> some View {
        if let colorScheme {
            preferredColorScheme(colorScheme)
        } else {
            self
        }
    }
}

@MainActor
private struct AppDependencies {
    let container: ModelContainer
    let analyticsClient: any AnalyticsClient
    let photographLibrary: PhotographLibrary
    let subscriptionAccessModel: SubscriptionAccessModel
    let onboardingDefaults: UserDefaults
}
