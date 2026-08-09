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
    @Environment(\.modelContext) private var context
    @State private var selectedTab = AppTab.today
    @State private var setupModel = OwnerSetupReadinessModel()
    @State private var presentsInitialSetup = false
    @State private var resolvedInitialSetup = false

    var body: some View {
        Group {
            switch setupModel.loadState {
            case .loading where !resolvedInitialSetup:
                ProgressView("Loading FarrierFlow…")
            case .failed where !resolvedInitialSetup:
                ContentUnavailableView {
                    Label("FarrierFlow Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("FarrierFlow couldn’t load your business setup.")
                } actions: {
                    Button("Retry", action: resolveInitialSetup)
                }
            default:
                if presentsInitialSetup {
                    OwnerSetupView(model: setupModel) {
                        presentsInitialSetup = false
                    }
                } else {
                    appTabs
                }
            }
        }
        .task {
            if !resolvedInitialSetup {
                resolveInitialSetup()
            }
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
        if setupModel.loadState == .loaded {
            presentsInitialSetup = !setupModel.hasValidIdentity
            resolvedInitialSetup = true
        }
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
            let mutationCoordinator = PersistenceMutationCoordinator()
            RootView()
                .modelContainer(container)
                .environment(mutationCoordinator)
                .environment(
                    PhotographLibrary(
                        container: container,
                        mutationCoordinator: mutationCoordinator,
                        fileStore: PhotographFileStore(
                            rootURL: FileManager.default.temporaryDirectory.appending(
                                path: "FarrierFlow-Preview-Photographs",
                                directoryHint: .isDirectory
                            )
                        )
                    )
                )
        case .failure:
            ModelContainerFailureView()
        }
    }
}

#Preview("Root — Populated") {
    RootPreview()
}
