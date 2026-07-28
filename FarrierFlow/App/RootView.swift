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
    @State private var selectedTab = AppTab.today

    var body: some View {
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
        .task {
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
        case .failure:
            ModelContainerFailureView()
        }
    }
}

#Preview("Root — Populated") {
    RootPreview()
}
