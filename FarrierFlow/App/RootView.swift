//
//  RootView.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
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
        case .failure:
            ModelContainerFailureView()
        }
    }
}

#Preview("Root — Populated") {
    RootPreview()
}
