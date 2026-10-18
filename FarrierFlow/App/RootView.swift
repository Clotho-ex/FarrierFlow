//
//  RootView.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import Foundation
import AuthenticationServices
import Combine
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
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(\.modelContext) private var context
    @Environment(\.backupSync) private var backupSync
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedTab = AppTab.today
    @State private var setupModel = OwnerSetupReadinessModel()
    @State private var onboarding: OnboardingExperienceModel
    @State private var showsBackupInvitation = false
    private let onboardingDefaults: UserDefaults

    init(onboardingDefaults: UserDefaults = .standard) {
        self.onboardingDefaults = onboardingDefaults
        _onboarding = State(
            initialValue: OnboardingExperienceModel(defaults: onboardingDefaults)
        )
    }

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
                if onboarding.step != .completed {
                    OnboardingFlowView(
                        model: onboarding,
                        setupModel: setupModel
                    )
                } else {
                    switch SubscriptionRootRules.state(
                        access: subscription.access,
                        hasIdentity: setupModel.hasValidIdentity,
                        hasExistingBusinessData: setupModel.hasExistingBusinessData
                    ) {
                    case .loading:
                        ProgressView("Loading FarrierFlow…")
                    case .subscriptionWelcome:
                        SubscriptionWelcomeView()
                    case .subscriptionUnavailable:
                        SubscriptionWelcomeView()
                    case .ownerSetup:
                        OwnerSetupView(model: setupModel) { }
                    case .app:
                        appTabs
                    }
                }
            }
        }
        .navigationLinkIndicatorVisibility(.hidden)
        .environment(onboarding)
        .task {
            subscription.start()
            resolveInitialSetup()
            await reconcilePhotographs()
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await backupSync?.restore() }
            else if scenePhase == .background { backupSync?.runtime?.stop() }
        }
        .task(id: backupSync?.authenticationObservationID) { await backupSync?.observeAuthentication() }
        .task {
            for await connected in SyncConnectivity.changes() {
                guard !Task.isCancelled else { return }
                if connected, scenePhase == .active { await backupSync?.connectionBecameAvailable() }
            }
        }
        .task(id: cloudObservationScope) {
            if scenePhase == .active { await backupSync?.observeWorkspace() }
        }
        .task(id: backupInvitationReady) {
            if backupInvitationReady, backupSync?.consumeInvitation() == true { showsBackupInvitation = true }
        }
        .sheet(isPresented: $showsBackupInvitation) {
            BackupSyncSheet().dynamicTypeSize(dynamicTypeSize)
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)
            .filter { backupSync?.runtime?.acceptsSaveNotification($0) == true }) {
            backupSync?.runtime?.didSave($0)
        }
        .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
            Task { await backupSync?.signOut() }
        }
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in
            resolveInitialSetup()
        }
        .onChange(of: backupSync?.runtime?.restoredBusinessVersion) { _, version in
            guard version != nil else { return }
            resolveInitialSetup()
            onboarding.cloudBusinessDidRestore(hasValidBusinessProfile: setupModel.hasValidIdentity)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification
            )
        ) { _ in
            Task {
                await reconcilePhotographs()
                await backupSync?.retry()
            }
        }
    }

    private var cloudObservationScope: CloudObservationScope {
        .init(account: backupSync?.session?.accountID, workspace: backupSync?.runtime?.workspaceID,
              active: scenePhase == .active)
    }

    private var backupInvitationReady: Bool {
        onboarding.step == .completed && setupModel.hasValidIdentity &&
            onboardingDefaults.bool(forKey: "backupSync.newBusinessSetup") &&
            backupSync?.shouldOfferInvitation == true
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
            if !setupModel.hasValidIdentity && !setupModel.hasExistingBusinessData {
                onboardingDefaults.set(true, forKey: "backupSync.newBusinessSetup")
            }
            onboarding.resolve(
                hasValidBusinessProfile: setupModel.hasValidIdentity,
                hasExistingBusinessData: setupModel.hasExistingBusinessData,
                analyticsClient: analyticsClient
            )
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

private struct CloudObservationScope: Hashable {
    let account: UUID?
    let workspace: UUID?
    let active: Bool
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
                        client: StaticSubscriptionClient(isPro: true)
                    )
                )
        case .failure:
            ModelContainerFailureView()
        }
    }
}

@MainActor
struct StaticSubscriptionClient: SubscriptionClient {
    let isPro: Bool

    func customerInfo() async throws -> SubscriptionCustomerSnapshot {
        .init(hasActiveProEntitlement: isPro)
    }

    func offerings() async throws -> [SubscriptionPlan] {
        [
            .init(id: "annual", productID: SubscriptionProduct.yearly, kind: .annual, displayName: "Annual", localizedPrice: "$119.99", price: Decimal(string: "119.99"), currencyCode: "USD", subscriptionPeriod: "year", introductoryTrial: .init(duration: 2, unit: .week)),
            .init(id: "monthly", productID: SubscriptionProduct.monthly, kind: .monthly, displayName: "Monthly", localizedPrice: "$14.99", price: Decimal(string: "14.99"), currencyCode: "USD", subscriptionPeriod: "month", introductoryTrial: .init(duration: 2, unit: .week)),
        ]
    }

    func purchase(planID: String) async throws -> SubscriptionPurchaseResult {
        .init(customer: .init(hasActiveProEntitlement: isPro), wasCancelled: false)
    }

    func restorePurchases() async throws -> SubscriptionCustomerSnapshot {
        .init(hasActiveProEntitlement: isPro)
    }

    func customerInfoUpdates() async -> AsyncStream<SubscriptionCustomerSnapshot> {
        AsyncStream { $0.finish() }
    }
}

#Preview("Root — Populated") {
    RootPreview()
}
