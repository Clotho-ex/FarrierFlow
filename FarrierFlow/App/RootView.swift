//
//  RootView.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import OSLog
import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "PhotographReconciliation"
    )

    @Environment(PhotographLibrary.self) private var photographLibrary
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.modelContext) private var context
    @State private var selectedTab = AppTab.today
    @State private var setupModel = OwnerSetupReadinessModel()

    var body: some View {
        Group {
            switch setupModel.loadState {
            case .loading:
                ProgressView("Loading FarrierFlow…")
            case .failed:
                ContentUnavailableView {
                    Label("FarrierFlow Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("FarrierFlow couldn’t load your business setup.")
                } actions: {
                    Button("Retry", action: resolveInitialSetup)
                }
            case .loaded:
                switch SubscriptionRootRules.state(
                    access: subscription.access,
                    hasIdentity: setupModel.hasValidIdentity
                ) {
                case .loading:
                    ProgressView("Loading FarrierFlow…")
                case .subscriptionWelcome:
                    SubscriptionWelcomeView()
                case .ownerSetup:
                    OwnerSetupView(model: setupModel) {
                    }
                case .app:
                    appTabs
                }
            }
        }
        .task {
            subscription.start()
            resolveInitialSetup()
            await reconcilePhotographs()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification
            )
        ) { _ in
            Task {
                await reconcilePhotographs()
            }
        }
    }

    private var appTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max", value: .today) {
                TodayView()
            }

            Tab("Schedule", systemImage: "calendar", value: .schedule) {
                ScheduleView()
            }

            Tab("Clients", systemImage: "person.2", value: .clients) {
                ClientListView()
            }
        }
    }

    private func resolveInitialSetup() {
        setupModel.load(in: context)
    }

    private func reconcilePhotographs() async {
        do {
            try await photographLibrary.prepareAndReconcile()
        } catch {
            Self.logger.error(
                "Photograph reconciliation deferred: \(error, privacy: .public)"
            )
        }
    }
}

private struct RootPreview: View {
    private let containerResult: Result<ModelContainer, Error>

    init() {
        containerResult = Result { try ModelContainerFactory.preview() }
    }

    var body: some View {
        switch containerResult {
        case .success(let container):
            RootView()
                .modelContainer(container)
                .environment(
                    PhotographLibrary(
                        container: container,
                        fileStore: PhotographFileStore(
                            rootURL: FileManager.default.temporaryDirectory.appending(
                                path: "FarrierFlow-Preview-Photographs",
                                directoryHint: .isDirectory
                            )
                        )
                    )
                )
                .environment(
                    SubscriptionAccessModel(
                        source: StaticSubscriptionEntitlementSource(isEntitled: true)
                    )
                )
        case .failure:
            ModelContainerFailureView()
        }
    }
}

private nonisolated struct StaticSubscriptionEntitlementSource:
    SubscriptionEntitlementSource {
    let isEntitled: Bool

    func hasCurrentEntitlement(productIDs: Set<String>) async -> Bool {
        isEntitled
    }

    func updates(productIDs: Set<String>) async -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

#Preview("Root — Populated") {
    RootPreview()
}
